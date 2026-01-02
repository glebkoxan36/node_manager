"""
Админ CLI для Blockchain Module - Полный контроль над системой
"""

import asyncio
import json
import logging
import sys
import time
from typing import Dict, List, Optional, Any
from datetime import datetime
import aiohttp
import questionary
from rich.console import Console
from rich.table import Table
from rich.layout import Layout
from rich.live import Live
from rich.panel import Panel
from rich.progress import Progress, SpinnerColumn, TextColumn
from rich.syntax import Syntax
from rich.text import Text
import click

logger = logging.getLogger(__name__)
console = Console()

class AdminCLI:
    """Инструмент администратора для полного управления Blockchain Module"""
    
    def __init__(self):
        self.db_manager = None
        self.user_manager = None
        self.config_manager = None
        self.current_user = None
        self.is_authenticated = False
        
    async def initialize(self):
        """Инициализировать CLI администратора"""
        try:
            from .database import SQLiteDBManager
            from .users import UserManager
            from .config import ConfigManager
            
            self.db_manager = SQLiteDBManager("blockchain_module.db")
            await self.db_manager.initialize()
            
            self.user_manager = UserManager("blockchain_module.db")
            await self.user_manager.initialize()
            
            self.config_manager = ConfigManager()
            
            await self.show_welcome()
            return True
        except Exception as e:
            console.print(f"[red]Ошибка инициализации: {e}[/red]")
            return False
    
    async def show_welcome(self):
        """Показать приветственное сообщение администратора"""
        console.print(Panel.fit(
            "[bold red]Админ Панель - Blockchain Module[/bold red]\n"
            "[yellow]Версия 2.0.0 - Полный контроль над системой[/yellow]",
            border_style="red"
        ))
        
        await self.admin_login()
    
    async def admin_login(self):
        """Вход администратора"""
        console.print("\n[bold]Вход администратора[/bold]")
        
        # Получаем API ключ администратора из базы
        async with self.db_manager.connection.cursor() as cursor:
            await cursor.execute("SELECT api_key FROM users WHERE role = 'admin' AND is_active = 1")
            row = await cursor.fetchone()
            
            if row:
                admin_api_key = row[0]
                console.print(f"[yellow]API ключ администратора: {admin_api_key}[/yellow]")
                console.print("[green]Используйте этот ключ для входа в систему[/green]")
            
        api_key = await questionary.text(
            "Введите API ключ администратора:",
            password=True
        ).unsafe_ask_async()
        
        if api_key:
            user = await self.user_manager.authenticate_user(api_key)
            if user and user.get('role') == 'admin':
                self.current_user = user
                self.is_authenticated = True
                console.print(f"[green]Успешный вход как администратор[/green]")
                await self.main_menu()
            else:
                console.print("[red]Неверный API ключ или недостаточно прав[/red]")
    
    async def main_menu(self):
        """Главное меню администратора"""
        while self.is_authenticated:
            action = await questionary.select(
                "Главное меню администратора:",
                choices=[
                    "Управление пользователями",
                    "Управление средствами",
                    "Мониторинг системы",
                    "Настройки системы",
                    "Статистика системы",
                    "Выйти"
                ]
            ).unsafe_ask_async()
            
            if action == "Управление пользователями":
                await self.user_management()
            elif action == "Управление средствами":
                await self.funds_management()
            elif action == "Мониторинг системы":
                await self.system_monitoring()
            elif action == "Настройки системы":
                await self.system_settings()
            elif action == "Статистика системы":
                await self.system_stats()
            elif action == "Выйти":
                await self.logout()
                break
    
    async def user_management(self):
        """Управление пользователями"""
        while True:
            action = await questionary.select(
                "Управление пользователями:",
                choices=[
                    "Список пользователей",
                    "Создать пользователя",
                    "Редактировать пользователя",
                    "Удалить пользователя",
                    "Сгенерировать API ключ",
                    "Назад"
                ]
            ).unsafe_ask_async()
            
            if action == "Список пользователей":
                await self.list_users()
            elif action == "Создать пользователя":
                await self.create_user()
            elif action == "Редактировать пользователя":
                await self.edit_user()
            elif action == "Удалить пользователя":
                await self.delete_user()
            elif action == "Сгенерировать API ключ":
                await self.generate_api_key()
            elif action == "Назад":
                break
    
    async def list_users(self):
        """Показать список всех пользователей"""
        with console.status("[bold green]Загрузка списка пользователей...[/bold green]"):
            result = await self.user_manager.list_users()
            
            if result['success']:
                users = result.get('users', [])
                
                if users:
                    table = Table(title="Пользователи системы", show_header=True, header_style="bold magenta")
                    table.add_column("ID", style="cyan")
                    table.add_column("Имя", style="green")
                    table.add_column("Email", style="yellow")
                    table.add_column("Роль", style="blue")
                    table.add_column("Статус", style="white")
                    table.add_column("Создан", style="white")
                    
                    for user in users:
                        status_color = "green" if user['status'] == 'active' else "red"
                        table.add_row(
                            str(user['id']),
                            user['username'],
                            user.get('email', ''),
                            user['role'],
                            f"[{status_color}]{user['status']}[/{status_color}]",
                            user['created_at'][:10] if user['created_at'] else 'N/A'
                        )
                    
                    console.print(table)
                else:
                    console.print("[yellow]Нет пользователей[/yellow]")
            else:
                console.print(f"[red]Ошибка: {result.get('error', 'Unknown error')}[/red]")
        
        await questionary.press_any_key_to_continue("Нажмите любую клавишу для продолжения...").unsafe_ask_async()
    
    async def create_user(self):
        """Создать нового пользователя"""
        console.print("\n[bold]Создание нового пользователя[/bold]")
        
        username = await questionary.text(
            "Имя пользователя:"
        ).unsafe_ask_async()
        
        email = await questionary.text(
            "Email (опционально):"
        ).unsafe_ask_async()
        
        role = await questionary.select(
            "Роль пользователя:",
            choices=['user', 'admin', 'viewer']
        ).unsafe_ask_async()
        
        if username:
            # Запрашиваем квоты
            console.print("\n[bold]Настройка квот пользователя:[/bold]")
            
            max_addresses = await questionary.text(
                "Макс. отслеживаемых адресов:",
                default="100"
            ).unsafe_ask_async()
            
            max_api_calls = await questionary.text(
                "Макс. API вызовов в день:",
                default="10000"
            ).unsafe_ask_async()
            
            max_monitors = await questionary.text(
                "Макс. одновременных мониторов:",
                default="5"
            ).unsafe_ask_async()
            
            can_collect = await questionary.confirm(
                "Разрешить сбор средств?",
                default=False
            ).unsafe_ask_async()
            
            quotas = {
                'max_monitored_addresses': int(max_addresses),
                'max_daily_api_calls': int(max_api_calls),
                'max_concurrent_monitors': int(max_monitors),
                'can_collect_funds': 1 if can_collect else 0,
                'can_create_addresses': 1,
                'can_view_transactions': 1
            }
            
            with console.status("[bold green]Создание пользователя...[/bold green]"):
                result = await self.user_manager.create_user(username, email, role, quotas)
                
                if result['success']:
                    console.print(Panel.fit(
                        f"[green]Пользователь создан![/green]\n\n"
                        f"Детали:\n"
                        f"  ID: {result['user_id']}\n"
                        f"  Имя: {result['username']}\n"
                        f"  Роль: {result['role']}\n"
                        f"  API ключ: {result['api_key']}\n\n"
                        f"[red]Сохраните API ключ! Он больше не будет показан.[/red]",
                        title="Новый пользователь",
                        border_style="green"
                    ))
                else:
                    console.print(f"[red]Ошибка: {result['error']}[/red]")
        
        await questionary.press_any_key_to_continue("Нажмите любую клавишу для продолжения...").unsafe_ask_async()
    
    async def edit_user(self):
        """Редактировать пользователя"""
        user_id = await questionary.text(
            "ID пользователя для редактирования:"
        ).unsafe_ask_async()
        
        if user_id:
            try:
                user_id = int(user_id)
                user = await self.user_manager.get_user_by_id(user_id)
                
                if user:
                    console.print(Panel.fit(
                        f"Редактирование пользователя:\n"
                        f" ID: {user['id']}\n"
                        f" Имя: {user['username']}\n"
                        f" Email: {user.get('email', 'Не указан')}\n"
                        f" Роль: {user['role']}\n"
                        f" Статус: {user['status']}",
                        title="Информация о пользователе",
                        border_style="cyan"
                    ))
                    
                    # Запрашиваем изменения
                    new_email = await questionary.text(
                        f"Новый email (текущий: {user.get('email', '')}):",
                        default=user.get('email', '')
                    ).unsafe_ask_async()
                    
                    new_role = await questionary.select(
                        f"Новая роль (текущая: {user['role']}):",
                        choices=['user', 'admin', 'viewer'],
                        default=user['role']
                    ).unsafe_ask_async()
                    
                    new_status = await questionary.select(
                        f"Новый статус (текущий: {user['status']}):",
                        choices=['active', 'inactive', 'suspended', 'banned'],
                        default=user['status']
                    ).unsafe_ask_async()
                    
                    # Запрашиваем квоты
                    console.print("\n[bold]Обновление квот:[/bold]")
                    
                    max_addresses = await questionary.text(
                        f"Макс. отслеживаемых адресов (текущее: {user.get('max_monitored_addresses', 100)}):",
                        default=str(user.get('max_monitored_addresses', 100))
                    ).unsafe_ask_async()
                    
                    max_api_calls = await questionary.text(
                        f"Макс. API вызовов в день (текущее: {user.get('max_daily_api_calls', 10000)}):",
                        default=str(user.get('max_daily_api_calls', 10000))
                    ).unsafe_ask_async()
                    
                    max_monitors = await questionary.text(
                        f"Макс. одновременных мониторов (текущее: {user.get('max_concurrent_monitors', 5)}):",
                        default=str(user.get('max_concurrent_monitors', 5))
                    ).unsafe_ask_async()
                    
                    can_collect = await questionary.confirm(
                        f"Разрешить сбор средств? (текущее: {'Да' if user.get('can_collect_funds') else 'Нет'}):",
                        default=bool(user.get('can_collect_funds'))
                    ).unsafe_ask_async()
                    
                    updates = {}
                    if new_email != user.get('email'):
                        updates['email'] = new_email
                    if new_role != user['role']:
                        updates['role'] = new_role
                    if new_status != user['status']:
                        updates['status'] = new_status
                    
                    quotas = {
                        'max_monitored_addresses': int(max_addresses),
                        'max_daily_api_calls': int(max_api_calls),
                        'max_concurrent_monitors': int(max_monitors),
                        'can_collect_funds': 1 if can_collect else 0,
                        'can_create_addresses': user.get('can_create_addresses', 1),
                        'can_view_transactions': user.get('can_view_transactions', 1)
                    }
                    updates['quotas'] = quotas
                    
                    if updates:
                        confirm = await questionary.confirm(
                            "Сохранить изменения?",
                            default=True
                        ).unsafe_ask_async()
                        
                        if confirm:
                            with console.status("[bold green]Сохранение изменений...[/bold green]"):
                                success = await self.user_manager.update_user(user_id, updates)
                                
                                if success:
                                    console.print("[green]Изменения сохранены[/green]")
                                else:
                                    console.print("[red]Ошибка сохранения изменений[/red]")
                    else:
                        console.print("[yellow]Изменений не внесено[/yellow]")
                else:
                    console.print("[red]Пользователь не найден[/red]")
            except ValueError:
                console.print("[red]Неверный ID пользователя[/red]")
        
        await questionary.press_any_key_to_continue("Нажмите любую клавишу для продолжения...").unsafe_ask_async()
    
    async def delete_user(self):
        """Удалить пользователя"""
        user_id = await questionary.text(
            "ID пользователя для удаления:"
        ).unsafe_ask_async()
        
        if user_id:
            try:
                user_id = int(user_id)
                
                confirm = await questionary.confirm(
                    "Вы уверены? Это действие нельзя отменить.",
                    default=False
                ).unsafe_ask_async()
                
                if confirm:
                    with console.status("[bold green]Удаление пользователя...[/bold green]"):
                        success = await self.user_manager.delete_user(user_id)
                        
                        if success:
                            console.print("[green]Пользователь удален[/green]")
                        else:
                            console.print("[red]Ошибка удаления пользователя[/red]")
            except ValueError:
                console.print("[red]Неверный ID пользователя[/red]")
        
        await questionary.press_any_key_to_continue("Нажмите любую клавишу для продолжения...").unsafe_ask_async()
    
    async def generate_api_key(self):
        """Сгенерировать новый API ключ для пользователя"""
        user_id = await questionary.text(
            "ID пользователя для генерации API ключа:"
        ).unsafe_ask_async()
        
        if user_id:
            try:
                user_id = int(user_id)
                
                confirm = await questionary.confirm(
                    "Вы уверены? Старый ключ перестанет работать.",
                    default=False
                ).unsafe_ask_async()
                
                if confirm:
                    with console.status("[bold green]Генерация API ключа...[/bold green]"):
                        new_api_key = await self.user_manager.regenerate_api_key(user_id)
                        
                        if new_api_key:
                            console.print(Panel.fit(
                                f"[green]API ключ сгенерирован![/green]\n\n"
                                f"[bold yellow]{new_api_key}[/bold yellow]\n\n"
                                f"[red]Сохраните этот ключ! Он больше не будет показан.[/red]",
                                border_style="green"
                            ))
                        else:
                            console.print("[red]Ошибка генерации API ключа[/red]")
            except ValueError:
                console.print("[red]Неверный ID пользователя[/red]")
        
        await questionary.press_any_key_to_continue("Нажмите любую клавишу для продолжения...").unsafe_ask_async()
    
    async def funds_management(self):
        """Управление средствами"""
        while True:
            action = await questionary.select(
                "Управление средствами:",
                choices=[
                    "Балансы пользователей",
                    "Собрать средства",
                    "История сборов",
                    "Назад"
                ]
            ).unsafe_ask_async()
            
            if action == "Балансы пользователей":
                await self.user_balances()
            elif action == "Собрать средства":
                await self.collect_funds_admin()
            elif action == "История сборов":
                await self.collection_history()
            elif action == "Назад":
                break
    
    async def user_balances(self):
        """Показать балансы пользователей"""
        console.print("\n[bold]Балансы пользователей[/bold]")
        console.print("[yellow]Функция в разработке[/yellow]")
        await questionary.press_any_key_to_continue("Нажмите любую клавишу для продолжения...").unsafe_ask_async()
    
    async def collect_funds_admin(self):
        """Собрать средства (админ)"""
        console.print("\n[bold]Сбор средств[/bold]")
        
        user_id = await questionary.text(
            "ID пользователя:"
        ).unsafe_ask_async()
        
        coin = await questionary.text(
            "Монета (BTC, LTC, DOGE):"
        ).unsafe_ask_async()
        
        address = await questionary.text(
            "Адрес источника:"
        ).unsafe_ask_async()
        
        private_key = await questionary.text(
            "Приватный ключ (WIF формат):",
            password=True
        ).unsafe_ask_async()
        
        master_address = await questionary.text(
            "Мастер-адрес (куда переводить):"
        ).unsafe_ask_async()
        
        if user_id and coin and address and private_key and master_address:
            console.print("[yellow]Внимание: Операция сбора средств необратима![/yellow]")
            
            confirm = await questionary.confirm(
                "Продолжить сбор средств?",
                default=False
            ).unsafe_ask_async()
            
            if confirm:
                try:
                    user_id_int = int(user_id)
                    from . import create_funds_collector
                    
                    collector = await create_funds_collector(
                        user_id=user_id_int,
                        coin_symbol=coin,
                        master_address=master_address
                    )
                    
                    result = await collector.collect_funds(address, private_key, self.db_manager)
                    
                    if result.get('success'):
                        console.print(Panel.fit(
                            f"[green]Сбор средств выполнен успешно![/green]\n\n"
                            f"Детали:\n"
                            f"  Монета: {result.get('coin', 'N/A')}\n"
                            f"  TXID: {result.get('txid', 'N/A')}\n"
                            f"  Отправлено: {result.get('amount_sent', 0):.8f}\n"
                            f"  Всего: {result.get('total_amount', 0):.8f}\n"
                            f"  Комиссия: {result.get('fee', 0):.8f}\n"
                            f"  От: {result.get('from_address', 'N/A')}\n"
                            f"  Кому: {result.get('to_address', 'N/A')}",
                            title="Результат сбора средств",
                            border_style="green"
                        ))
                    else:
                        console.print(f"[red]Ошибка: {result.get('error', 'Unknown error')}[/red]")
                except Exception as e:
                    console.print(f"[red]Ошибка: {e}[/red]")
        
        await questionary.press_any_key_to_continue("Нажмите любую клавишу для продолжения...").unsafe_ask_async()
    
    async def collection_history(self):
        """История сборов средств"""
        with console.status("[bold green]Загрузка истории сборов...[/bold green]"):
            async with self.db_manager.connection.cursor() as cursor:
                await cursor.execute('''
                    SELECT c.*, u.username 
                    FROM collections c
                    LEFT JOIN users u ON c.user_id = u.id
                    ORDER BY c.created_at DESC
                    LIMIT 50
                ''')
                rows = await cursor.fetchall()
                columns = [description[0] for description in cursor.description]
                
                if rows:
                    table = Table(title="История сборов средств", show_header=True, header_style="bold magenta")
                    table.add_column("ID", style="cyan")
                    table.add_column("Пользователь", style="green")
                    table.add_column("Монета", style="yellow")
                    table.add_column("Сумма", style="blue")
                    table.add_column("TXID", style="white")
                    table.add_column("Дата", style="white")
                    
                    for row in rows:
                        data = dict(zip(columns, row))
                        txid_short = data['txid'][:10] + '...' if len(data['txid']) > 10 else data['txid']
                        table.add_row(
                            str(data['id']),
                            data['username'],
                            data['coin'],
                            f"{data['amount_sent']:.8f}",
                            txid_short,
                            data['created_at'][:19] if data['created_at'] else 'N/A'
                        )
                    
                    console.print(table)
                else:
                    console.print("[yellow]Нет записей о сборах средств[/yellow]")
        
        await questionary.press_any_key_to_continue("Нажмите любую клавишу для продолжения...").unsafe_ask_async()
    
    async def system_monitoring(self):
        """Мониторинг системы"""
        while True:
            action = await questionary.select(
                "Мониторинг системы:",
                choices=[
                    "Статус мониторов",
                    "Отслеживаемые адреса",
                    "Активные транзакции",
                    "Здоровье системы",
                    "Назад"
                ]
            ).unsafe_ask_async()
            
            if action == "Статус мониторов":
                await self.monitor_status()
            elif action == "Отслеживаемые адреса":
                await self.monitored_addresses()
            elif action == "Активные транзакции":
                await self.active_transactions()
            elif action == "Здоровье системы":
                await self.system_health()
            elif action == "Назад":
                break
    
    async def monitor_status(self):
        """Статус мониторов"""
        with console.status("[bold green]Загрузка статуса мониторов...[/bold green]"):
            async with self.db_manager.connection.cursor() as cursor:
                await cursor.execute('''
                    SELECT um.*, u.username 
                    FROM user_monitors um
                    LEFT JOIN users u ON um.user_id = u.id
                    WHERE um.is_active = 1
                    ORDER BY um.last_active DESC
                ''')
                rows = await cursor.fetchall()
                columns = [description[0] for description in cursor.description]
                
                if rows:
                    table = Table(title="Статус мониторов", show_header=True, header_style="bold magenta")
                    table.add_column("ID", style="cyan")
                    table.add_column("Пользователь", style="green")
                    table.add_column("Монета", style="yellow")
                    table.add_column("Статус", style="blue")
                    table.add_column("Последняя активность", style="white")
                    
                    for row in rows:
                        data = dict(zip(columns, row))
                        status_color = "green" if data['status'] == 'running' else "red"
                        table.add_row(
                            str(data['id']),
                            data['username'],
                            data['coin'],
                            f"[{status_color}]{data['status']}[/{status_color}]",
                            data['last_active'][:19] if data['last_active'] else 'N/A'
                        )
                    
                    console.print(table)
                else:
                    console.print("[yellow]Нет активных мониторов[/yellow]")
        
        await questionary.press_any_key_to_continue("Нажмите любую клавишу для продолжения...").unsafe_ask_async()
    
    async def monitored_addresses(self):
        """Отслеживаемые адреса"""
        with console.status("[bold green]Загрузка отслеживаемых адресов...[/bold green]"):
            async with self.db_manager.connection.cursor() as cursor:
                await cursor.execute('''
                    SELECT ma.*, u.username 
                    FROM monitored_addresses ma
                    LEFT JOIN users u ON ma.user_id = u.id
                    WHERE ma.is_active = 1
                    ORDER BY ma.added_at DESC
                    LIMIT 50
                ''')
                rows = await cursor.fetchall()
                columns = [description[0] for description in cursor.description]
                
                if rows:
                    table = Table(title="Отслеживаемые адреса", show_header=True, header_style="bold magenta")
                    table.add_column("ID", style="cyan")
                    table.add_column("Пользователь", style="green")
                    table.add_column("Монета", style="yellow")
                    table.add_column("Адрес", style="blue")
                    table.add_column("Дата добавления", style="white")
                    
                    for row in rows:
                        data = dict(zip(columns, row))
                        address_short = data['address'][:15] + '...' if len(data['address']) > 15 else data['address']
                        table.add_row(
                            str(data['id']),
                            data['username'],
                            data['coin'],
                            address_short,
                            data['added_at'][:19] if data['added_at'] else 'N/A'
                        )
                    
                    console.print(table)
                else:
                    console.print("[yellow]Нет отслеживаемых адресов[/yellow]")
        
        await questionary.press_any_key_to_continue("Нажмите любую клавишу для продолжения...").unsafe_ask_async()
    
    async def active_transactions(self):
        """Активные транзакции"""
        with console.status("[bold green]Загрузка активных транзакций...[/bold green]"):
            async with self.db_manager.connection.cursor() as cursor:
                await cursor.execute('''
                    SELECT t.*, u.username 
                    FROM transactions t
                    LEFT JOIN users u ON t.user_id = u.id
                    WHERE t.status IN ('pending', 'mempool', 'confirming')
                    ORDER BY t.timestamp DESC
                    LIMIT 50
                ''')
                rows = await cursor.fetchall()
                columns = [description[0] for description in cursor.description]
                
                if rows:
                    table = Table(title="Активные транзакции", show_header=True, header_style="bold magenta")
                    table.add_column("ID", style="cyan")
                    table.add_column("Пользователь", style="green")
                    table.add_column("Монета", style="yellow")
                    table.add_column("TXID", style="blue")
                    table.add_column("Сумма", style="white")
                    table.add_column("Статус", style="white")
                    
                    for row in rows:
                        data = dict(zip(columns, row))
                        txid_short = data['txid'][:10] + '...' if len(data['txid']) > 10 else data['txid']
                        status_color = "yellow" if data['status'] in ['pending', 'mempool'] else "green"
                        table.add_row(
                            str(data['id']),
                            data['username'],
                            data['coin'],
                            txid_short,
                            f"{data['amount']:.8f}",
                            f"[{status_color}]{data['status']}[/{status_color}]"
                        )
                    
                    console.print(table)
                else:
                    console.print("[yellow]Нет активных транзакций[/yellow]")
        
        await questionary.press_any_key_to_continue("Нажмите любую клавишу для продолжения...").unsafe_ask_async()
    
    async def system_health(self):
        """Здоровье системы"""
        try:
            from .health_check import HealthChecker
            
            health_checker = HealthChecker()
            
            with console.status("[bold green]Проверка здоровья системы...[/bold green]"):
                report = await health_checker.comprehensive_check()
                
                if report:
                    table = Table(title="Здоровье системы", show_header=True, header_style="bold magenta")
                    table.add_column("Компонент", style="cyan")
                    table.add_column("Статус", style="green")
                    table.add_column("Время ответа", style="yellow")
                    
                    for name, component in report.get('components', {}).items():
                        status_color = "green" if component['status'] == 'healthy' else "red"
                        table.add_row(
                            name,
                            f"[{status_color}]{component['status']}[/{status_color}]",
                            f"{component['response_time']:.3f}s"
                        )
                    
                    console.print(table)
                    
                    # Сводка
                    summary = report.get('summary', {})
                    console.print(f"\nСводка: Здоровых: {summary.get('healthy', 0)}, "
                                 f"Проблемных: {summary.get('degraded', 0) + summary.get('unhealthy', 0)}")
                else:
                    console.print("[yellow]Не удалось получить данные о здоровье системы[/yellow]")
        except Exception as e:
            console.print(f"[red]Ошибка проверки здоровья: {e}[/red]")
        
        await questionary.press_any_key_to_continue("Нажмите любую клавишу для продолжения...").unsafe_ask_async()
    
    async def system_settings(self):
        """Настройки системы"""
        while True:
            action = await questionary.select(
                "Настройки системы:",
                choices=[
                    "Конфигурация модуля",
                    "Настройки монет",
                    "Настройки мониторинга",
                    "Настройки REST API",
                    "Перезагрузить конфигурацию",
                    "Сохранить конфигурацию",
                    "Назад"
                ]
            ).unsafe_ask_async()
            
            if action == "Конфигурация модуля":
                await self.module_config()
            elif action == "Настройки монет":
                await self.coin_settings()
            elif action == "Настройки мониторинга":
                await self.monitoring_settings()
            elif action == "Настройки REST API":
                await self.api_settings()
            elif action == "Перезагрузить конфигурацию":
                await self.reload_config()
            elif action == "Сохранить конфигурацию":
                await self.save_config()
            elif action == "Назад":
                break
    
    async def module_config(self):
        """Конфигурация модуля"""
        config_summary = self.config_manager.get_config_summary()
        
        console.print(Panel.fit(
            f"[bold]Конфигурация модуля[/bold]\n\n"
            f"Файл конфигурации: {config_summary.get('config_file', 'N/A')}\n"
            f"Поддерживаемые монеты: {len(config_summary.get('configured_coins', []))}\n"
            f"Многопользовательский режим: {'Включен' if config_summary.get('multiuser_enabled') else 'Выключен'}\n"
            f"API ключ: {'Настроен' if self.config_manager.get_module_setting('api_key') else 'Не настроен'}",
            title="Конфигурация модуля",
            border_style="cyan"
        ))
        
        await questionary.press_any_key_to_continue("Нажмите любую клавишу для продолжения...").unsafe_ask_async()
    
    async def coin_settings(self):
        """Настройки монет"""
        coins = self.config_manager.get_all_coins()
        
        if coins:
            table = Table(title="Настройки монет", show_header=True, header_style="bold magenta")
            table.add_column("Символ", style="cyan")
            table.add_column("Название", style="green")
            table.add_column("Делимость", style="yellow")
            table.add_column("URL Blockbook", style="blue")
            
            for coin in coins:
                config = self.config_manager.get_coin_config(coin)
                table.add_row(
                    config.get('symbol', coin),
                    config.get('name', coin),
                    str(config.get('decimals', 8)),
                    config.get('blockbook_url', 'N/A')[:40] + '...'
                )
            
            console.print(table)
            
            # Действия с монетами
            action = await questionary.select(
                "Действия:",
                choices=[
                    "Добавить монету",
                    "Редактировать монету",
                    "Удалить монету",
                    "Назад"
                ]
            ).unsafe_ask_async()
            
            if action == "Добавить монету":
                await self.add_coin()
            elif action == "Редактировать монету":
                await self.edit_coin()
            elif action == "Удалить монету":
                await self.delete_coin()
        else:
            console.print("[yellow]Нет настроенных монет[/yellow]")
        
        await questionary.press_any_key_to_continue("Нажмите любую клавишу для продолжения...").unsafe_ask_async()
    
    async def add_coin(self):
        """Добавить новую монету"""
        console.print("\n[bold]Добавление новой монеты[/bold]")
        
        symbol = await questionary.text(
            "Символ монеты (например, BTC):"
        ).unsafe_ask_async()
        
        name = await questionary.text(
            "Название монеты:"
        ).unsafe_ask_async()
        
        decimals = await questionary.text(
            "Делимость (обычно 8):",
            default="8"
        ).unsafe_ask_async()
        
        blockbook_url = await questionary.text(
            "URL Blockbook API:",
            default=f"https://{symbol.lower()}book.nownodes.io"
        ).unsafe_ask_async()
        
        required_confirmations = await questionary.text(
            "Требуемые подтверждения:",
            default="3"
        ).unsafe_ask_async()
        
        min_collection = await questionary.text(
            "Минимальная сумма сбора:",
            default="0.001"
        ).unsafe_ask_async()
        
        collection_fee = await questionary.text(
            "Комиссия сбора:",
            default="0.0001"
        ).unsafe_ask_async()
        
        if symbol and name:
            config = {
                'symbol': symbol.upper(),
                'name': name,
                'decimals': int(decimals),
                'blockbook_url': blockbook_url,
                'required_confirmations': int(required_confirmations),
                'min_collection_amount': float(min_collection),
                'collection_fee': float(collection_fee)
            }
            
            success = self.config_manager.set_coin_config(symbol.upper(), config)
            
            if success:
                console.print(f"[green]Монета {symbol} добавлена[/green]")
            else:
                console.print("[red]Ошибка добавления монеты[/red]")
    
    async def edit_coin(self):
        """Редактировать монету"""
        symbol = await questionary.text(
            "Символ монеты для редактирования:"
        ).unsafe_ask_async()
        
        if symbol:
            config = self.config_manager.get_coin_config(symbol)
            
            if config:
                console.print(Panel.fit(
                    f"Редактирование монеты {symbol}:\n"
                    f"Название: {config.get('name', 'N/A')}\n"
                    f"Делимость: {config.get('decimals', 8)}\n"
                    f"URL: {config.get('blockbook_url', 'N/A')}\n"
                    f"Подтверждения: {config.get('required_confirmations', 3)}\n"
                    f"Мин. сбор: {config.get('min_collection_amount', 0.001)}\n"
                    f"Комиссия: {config.get('collection_fee', 0.0001)}",
                    title=f"Конфигурация {symbol}",
                    border_style="cyan"
                ))
                
                # Здесь можно добавить редактирование полей
                console.print("[yellow]Редактирование в разработке[/yellow]")
            else:
                console.print(f"[red]Монета {symbol} не найдена[/red]")
    
    async def delete_coin(self):
        """Удалить монету"""
        symbol = await questionary.text(
            "Символ монеты для удаления:"
        ).unsafe_ask_async()
        
        if symbol:
            confirm = await questionary.confirm(
                f"Удалить монету {symbol}?",
                default=False
            ).unsafe_ask_async()
            
            if confirm:
                # Получаем текущие настройки
                config_data = self.config_manager.config_data
                coins = config_data.get('coins', {})
                
                if symbol.upper() in coins:
                    del coins[symbol.upper()]
                    config_data['coins'] = coins
                    
                    if self.config_manager.save_config():
                        console.print(f"[green]Монета {symbol} удалена[/green]")
                    else:
                        console.print("[red]Ошибка удаления монеты[/red]")
                else:
                    console.print(f"[red]Монета {symbol} не найдена[/red]")
    
    async def monitoring_settings(self):
        """Настройки мониторинга"""
        monitoring_config = self.config_manager.get_monitoring_config()
        
        console.print(Panel.fit(
            f"[bold]Настройки мониторинга[/bold]\n\n"
            f"Мониторинг: {'Включен' if monitoring_config.get('enabled') else 'Выключен'}\n"
            f"Порт Prometheus: {monitoring_config.get('prometheus_port', 9090)}\n"
            f"Префикс метрик: {monitoring_config.get('metrics_prefix', 'blockchain_module')}",
            title="Настройки мониторинга",
            border_style="cyan"
        ))
        
        await questionary.press_any_key_to_continue("Нажмите любую клавишу для продолжения...").unsafe_ask_async()
    
    async def api_settings(self):
        """Настройки REST API"""
        api_config = self.config_manager.get_rest_api_config()
        
        console.print(Panel.fit(
            f"[bold]Настройки REST API[/bold]\n\n"
            f"REST API: {'Включен' if api_config.get('enabled') else 'Выключен'}\n"
            f"Хост: {api_config.get('host', '0.0.0.0')}\n"
            f"Порт: {api_config.get('port', 8080)}\n"
            f"Требуется API ключ: {'Да' if api_config.get('api_key_required') else 'Нет'}\n"
            f"Лимит запросов: {api_config.get('rate_limit', 100)}\n"
            f"Аутентификация: {'Включена' if api_config.get('enable_auth') else 'Выключена'}",
            title="Настройки REST API",
            border_style="cyan"
        ))
        
        await questionary.press_any_key_to_continue("Нажмите любую клавишу для продолжения...").unsafe_ask_async()
    
    async def reload_config(self):
        """Перезагрузить конфигурацию"""
        with console.status("[bold green]Перезагрузка конфигурации...[/bold green]"):
            success = self.config_manager.load_config()
            
            if success:
                console.print("[green]Конфигурация перезагружена[/green]")
            else:
                console.print("[red]Ошибка перезагрузки конфигурации[/red]")
        
        await questionary.press_any_key_to_continue("Нажмите любую клавишу для продолжения...").unsafe_ask_async()
    
    async def save_config(self):
        """Сохранить конфигурацию"""
        with console.status("[bold green]Сохранение конфигурации...[/bold green]"):
            success = self.config_manager.save_config()
            
            if success:
                console.print("[green]Конфигурация сохранена[/green]")
            else:
                console.print("[red]Ошибка сохранения конфигурации[/red]")
        
        await questionary.press_any_key_to_continue("Нажмите любую клавишу для продолжения...").unsafe_ask_async()
    
    async def system_stats(self):
        """Статистика системы"""
        with console.status("[bold green]Загрузка статистики системы...[/bold green]"):
            stats = await self.db_manager.get_stats()
            
            if stats:
                table = Table(title="Статистика системы", show_header=True, header_style="bold magenta")
                table.add_column("Показатель", style="cyan")
                table.add_column("Значение", justify="right", style="green")
                
                for key, value in stats.items():
                    if key.endswith('_count'):
                        table.add_row(key.replace('_count', '').replace('_', ' ').title(), str(value))
                
                console.print(table)
            else:
                console.print("[yellow]Нет данных статистики[/yellow]")
        
        await questionary.press_any_key_to_continue("Нажмите любую клавишу для продолжения...").unsafe_ask_async()
    
    async def logout(self):
        """Выйти из системы"""
        self.is_authenticated = False
        self.current_user = None
        console.print("[yellow]Вы вышли из системы[/yellow]")
    
    async def run(self):
        """Запустить CLI"""
        try:
            success = await self.initialize()
            if not success:
                console.print("[red]Не удалось инициализировать CLI[/red]")
                return
            
            # Ждем, пока пользователь не выйдет
            while self.is_authenticated:
                await asyncio.sleep(1)
                
        except KeyboardInterrupt:
            console.print("\n[yellow]Выход по запросу пользователя[/yellow]")
        except Exception as e:
            console.print(f"[red]Ошибка: {e}[/red]")
            logger.error(f"CLI error: {e}", exc_info=True)
        finally:
            if self.db_manager:
                await self.db_manager.close()
            if self.user_manager:
                await self.user_manager.close()

# Командная строка Click
@click.group()
@click.pass_context
def cli(ctx):
    """Админ CLI для Blockchain Module - Полный контроль над системой"""
    ctx.ensure_object(dict)

@cli.command()
def interactive():
    """Запустить интерактивный режим админа"""
    cli_app = AdminCLI()
    asyncio.run(cli_app.run())

@cli.command()
@click.argument('username')
@click.option('--email', help='Email пользователя')
@click.option('--role', type=click.Choice(['user', 'admin', 'viewer']), default='user', help='Роль пользователя')
def create_user(username, email, role):
    """Создать нового пользователя"""
    
    async def do_create():
        try:
            from .database import SQLiteDBManager
            from .users import UserManager
            
            db_manager = SQLiteDBManager("blockchain_module.db")
            await db_manager.initialize()
            
            user_manager = UserManager("blockchain_module.db")
            await user_manager.initialize()
            
            quotas = {
                'max_monitored_addresses': 100,
                'max_daily_api_calls': 10000,
                'max_concurrent_monitors': 5,
                'can_collect_funds': 0,
                'can_create_addresses': 1,
                'can_view_transactions': 1
            }
            
            result = await user_manager.create_user(username, email, role, quotas)
            
            if result['success']:
                click.echo(click.style('Пользователь создан!', fg='green'))
                click.echo(f"ID: {result['user_id']}")
                click.echo(f"Имя: {result['username']}")
                click.echo(f"Роль: {result['role']}")
                click.echo(f"API Key: {result['api_key']}")
                click.echo(click.style('Сохраните этот ключ! Он больше не будет показан.', fg='red'))
            else:
                click.echo(click.style(f'Ошибка: {result["error"]}', fg='red'))
            
            await db_manager.close()
            
        except Exception as e:
            click.echo(click.style(f'Ошибка: {e}', fg='red'))
    
    asyncio.run(do_create())

@cli.command()
def list_users():
    """Показать список всех пользователей"""
    
    async def do_list():
        try:
            from .database import SQLiteDBManager
            from .users import UserManager
            
            db_manager = SQLiteDBManager("blockchain_module.db")
            await db_manager.initialize()
            
            user_manager = UserManager("blockchain_module.db")
            await user_manager.initialize()
            
            result = await user_manager.list_users()
            
            if result['success']:
                users = result.get('users', [])
                
                if users:
                    table = []
                    table.append(['ID', 'Имя', 'Email', 'Роль', 'Статус', 'Создан'])
                    table.append(['---', '---', '---', '---', '---', '---'])
                    
                    for user in users:
                        table.append([
                            str(user['id']),
                            user['username'],
                            user.get('email', ''),
                            user['role'],
                            user['status'],
                            user['created_at'][:10] if user['created_at'] else 'N/A'
                        ])
                    
                    # Выводим таблицу
                    col_width = [max(len(str(x)) for x in col) for col in zip(*table)]
                    for row in table:
                        line = " | ".join("{:{}}".format(str(x), col_width[i]) for i, x in enumerate(row))
                        click.echo(line)
                        if row[0] == 'ID':
                            click.echo("-" * len(line))
                else:
                    click.echo("Нет пользователей")
            else:
                click.echo(click.style(f'Ошибка: {result["error"]}', fg='red'))
            
            await db_manager.close()
            
        except Exception as e:
            click.echo(click.style(f'Ошибка: {e}', fg='red'))
    
    asyncio.run(do_list())

@cli.command()
@click.argument('user_id', type=int)
def reset_api_key(user_id):
    """Сбросить API ключ пользователя"""
    
    async def do_reset():
        try:
            from .database import SQLiteDBManager
            from .users import UserManager
            
            db_manager = SQLiteDBManager("blockchain_module.db")
            await db_manager.initialize()
            
            user_manager = UserManager("blockchain_module.db")
            await user_manager.initialize()
            
            new_api_key = await user_manager.regenerate_api_key(user_id)
            
            if new_api_key:
                click.echo(click.style('API ключ сброшен!', fg='green'))
                click.echo(f"Новый API Key: {new_api_key}")
                click.echo(click.style('Сохраните этот ключ! Он больше не будет показан.', fg='red'))
            else:
                click.echo(click.style('Ошибка сброса API ключа', fg='red'))
            
            await db_manager.close()
            
        except Exception as e:
            click.echo(click.style(f'Ошибка: {e}', fg='red'))
    
    asyncio.run(do_reset())

@cli.command()
def system_status():
    """Показать статус системы"""
    
    async def do_status():
        try:
            from .database import SQLiteDBManager
            from .health_check import HealthChecker
            
            db_manager = SQLiteDBManager("blockchain_module.db")
            await db_manager.initialize()
            
            health_checker = HealthChecker()
            report = await health_checker.comprehensive_check()
            
            if report:
                click.echo(click.style('Система работает', fg='green'))
                click.echo(f"Общий статус: {report['status']}")
                click.echo(f"Время ответа: {report['response_time']:.3f} сек")
                
                summary = report.get('summary', {})
                click.echo(f"Компонентов: {summary.get('total_components', 0)}")
                click.echo(f"Здоровых: {summary.get('healthy', 0)}")
                click.echo(f"Проблемных: {summary.get('degraded', 0) + summary.get('unhealthy', 0)}")
            else:
                click.echo(click.style('Не удалось получить статус системы', fg='red'))
            
            await db_manager.close()
            
        except Exception as e:
            click.echo(click.style(f'Ошибка: {e}', fg='red'))
    
    asyncio.run(do_status())

@cli.command()
def admin_key():
    """Показать API ключ администратора"""
    
    async def do_admin_key():
        try:
            from .database import SQLiteDBManager
            
            db_manager = SQLiteDBManager("blockchain_module.db")
            await db_manager.initialize()
            
            async with db_manager.connection.cursor() as cursor:
                await cursor.execute("SELECT api_key FROM users WHERE role = 'admin' AND is_active = 1 LIMIT 1")
                row = await cursor.fetchone()
                
                if row:
                    click.echo(f"API Key администратора: {row[0]}")
                else:
                    click.echo(click.style('Администратор не найден', fg='red'))
            
            await db_manager.close()
            
        except Exception as e:
            click.echo(click.style(f'Ошибка: {e}', fg='red'))
    
    asyncio.run(do_admin_key())

if __name__ == '__main__':
    cli()