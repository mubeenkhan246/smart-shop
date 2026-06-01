# Smart Shop

Smart Shop is an offline-first Flutter POS and inventory system for small shops. It includes billing, product stock, expiry alerts, suppliers, employees, salaries, commission, employee presence, approvals, reports, backups, and a laptop-hosted local database server for multi-device use on the same network.

## Screenshots

<div align="center">
  <img src="screenshots/login.png" alt="Login Screen" width="250"/>
  <img src="screenshots/dashboard.png" alt="Dashboard" width="250"/>
  <img src="screenshots/pos.png" alt="POS Billing" width="250"/>
</div>

<div align="center">
  <img src="screenshots/products.png" alt="Products" width="250"/>
  <img src="screenshots/cart.png" alt="Cart" width="250"/>
  <img src="screenshots/reports.png" alt="Reports" width="250"/>
</div>

> **Note:** Add your app screenshots to the `screenshots/` folder with the following names:
> - `login.png` - Login screen
> - `dashboard.png` - Dashboard/home screen
> - `pos.png` - POS billing screen
> - `products.png` - Products management
> - `cart.png` - Shopping cart
> - `reports.png` - Reports and analytics
> 
> Or add any screenshots you want and update the image references above.

## Main Features

- Multi-shop support with shop-specific employees and data
- Email/password login with strong password rules
- Role-based access for Admin, Editor, Seller, Editor + Seller, Manager, and Marketing Manager
- Admin-only delete controls for products, suppliers, and employees
- Admin approval flow for products and suppliers added by non-admin users
- POS billing with employee selection, stock control, invoices, and searchable recent invoices
- Product management with supplier, expiry date, low-stock alerts, and expiring-soon alerts
- Dashboard sales cards for Daily, Weekly, Monthly, Yearly, and custom date history
- Tap low-stock and expiry cards to view matching products
- Supplier details with all supplier products, sales, profit/loss, and date filters
- Employee profiles with salary, commission percent, phone, ID card number, address, photo, duty time, leave/rejoin history, and manager assignment
- Admin can see who is logged in, working now, offline, and each employee's last seen time
- Reports for sales, profit, payroll, salaries, commission, inventory, suppliers, and employee sales
- Searchable currency picker with international currency symbols
- Backup export/import, including local file saving and share option
- Flutter web support for employee access through a browser link
- Laptop database server powered by `restaurant_local_server`

## Default Login

Default accounts are created on first run:

| Role | Email | Password |
| --- | --- | --- |
| Admin | `admin@smartshop.local` | `Admin@123` |
| Editor | `editor@smartshop.local` | `Editor@123` |
| Seller | `seller@smartshop.local` | `Seller@123` |

Passwords must be at least 8 characters and include:

- Alphabet letter
- Number
- Special character

Example valid password:

```text
Admin@123
```

## User Roles

| Role | Access |
| --- | --- |
| Admin | Full app access, create shops, manage users, approve/decline requests, delete records, edit admin profile, export/import backups |
| Editor | Add/edit products and suppliers, but requests need admin approval and delete is blocked |
| Seller | Sell products from POS only |
| Editor + Seller | POS access plus product/supplier editing |
| Manager | POS access, product/supplier editing, and can have employees assigned under them |
| Marketing Manager | Manager-style role for marketing/team staff |

## Admin And Employees

The admin is the parent account for a shop. Employees are child accounts under that shop.

Admin can:

- Add, edit, and delete employees
- Assign employee role
- Assign manager
- Add salary and commission percent
- Add phone, ID card number, address, and profile photo
- Set duty start and duty end time
- Mark employee leave
- Rejoin leave employees
- See employee joining history
- See employee sales, earning, commission, and profit
- See who is logged in, working now, offline, and last seen

Admin is shown separately from the employee list and cannot be deleted as an employee.

## Supplier And Product Approval

When a non-admin user adds or edits products or suppliers, the request is saved as pending.

Admin can open the approvals button from the app bar and:

- Approve product
- Decline product
- Approve supplier
- Decline supplier

Only approved products and suppliers are shown in normal selling and listing flows.

## Requirements

- Flutter SDK
- Dart SDK included with Flutter
- Chrome or another supported browser for web
- macOS, Windows, Linux, Android, iOS, or Web target

Check setup:

```bash
flutter doctor
```

Install packages:

```bash
flutter pub get
```

## Run On One Device

Run macOS desktop:

```bash
flutter run -d macos
```

Run Chrome:

```bash
flutter run -d chrome
```

## Run For Employees On Same Wi-Fi

For multiple employees to use the app from phones or other computers, run two things on the laptop:

1. Smart Shop database server
2. Flutter web app server

### 1. Start The Laptop Database Server

```bash
dart run bin/smart_shop_server.dart
```

Default server address:

```text
http://localhost:9090
```

From another device on the same Wi-Fi:

```text
http://YOUR-LAPTOP-IP:9090
```

The server page only shows database/API status. It is not the shop app UI.

### 2. Start The Flutter Web App

Open a second terminal and run:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

Open the app on another phone or PC:

```text
http://YOUR-LAPTOP-IP:8080
```

Example:

```text
http://192.168.1.25:8080
```

When the web app opens from `http://YOUR-LAPTOP-IP:8080`, it automatically tries to use the database server at:

```text
http://YOUR-LAPTOP-IP:9090
```

## Find Your Laptop IP

On macOS:

```bash
ipconfig getifaddr en0
```

If that returns nothing, try:

```bash
ifconfig
```

Look for an address like:

```text
192.168.x.x
```

## If Phone Cannot Open The App

Check these items:

- Phone and laptop are connected to the same Wi-Fi
- VPN is off on both devices
- The Flutter web server command uses `--web-hostname 0.0.0.0`
- macOS firewall allows incoming connections for Flutter/Dart
- Router does not block device-to-device access
- Port `8080` is not already in use

If port `8080` is busy, use another port:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8081
```

Then open:

```text
http://YOUR-LAPTOP-IP:8081
```

## If Port 8080 Is Already In Use

Find the process:

```bash
lsof -i :8080
```

Stop it by PID:

```bash
kill PID_NUMBER
```

Or run Flutter on another port:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8081
```

## Laptop Server Options

Custom port:

```bash
dart run bin/smart_shop_server.dart --port 9090
```

Custom database folder:

```bash
dart run bin/smart_shop_server.dart --data-dir /Users/YOUR_NAME/SmartShopServer
```

Default database file:

```text
~/SmartShopServer/smart_shop_database.json
```

API endpoints:

```text
GET  /health
GET  /api/system/info
POST /api/smart-shop/auth/login
GET  /api/smart-shop/database
PUT  /api/smart-shop/database
POST /api/smart-shop/database/merge
GET  /api/smart-shop/tables/{table}
PUT  /api/smart-shop/tables/{table}
```

## Use A Custom Server URL

By default:

- Web app uses `http://same-host-as-app:9090`
- Desktop/mobile uses `http://localhost:9090`

You can build or run with a custom server URL:

```bash
flutter run -d chrome --dart-define=SMART_SHOP_SERVER_URL=http://192.168.1.25:9090
```

For web server:

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080 --dart-define=SMART_SHOP_SERVER_URL=http://192.168.1.25:9090
```

## Backups

Admin can use the backup button in the app bar.

Options:

- Save backup locally
- Share backup
- Import history backup

On desktop, local exports are saved in a Smart Shop backup folder. On web, the browser downloads a JSON backup file.

## Project Structure

```text
bin/
  smart_shop_server.dart      Laptop database server

lib/
  controllers/                Riverpod providers and business logic
  database/                   Hive database and remote sync layer
  models/                     App models
  services/                   Backup and invoice services
  utils/                      Formatters, IDs, password rules
  views/                      Screens
  widgets/                    Shared widgets

test/
  widget_test.dart            Basic app tests
```

## Quality Checks

Format:

```bash
dart format lib test bin
```

Analyze:

```bash
flutter analyze
```

Test:

```bash
flutter test
```

## Build

Build web:

```bash
flutter build web
```

Build macOS:

```bash
flutter build macos
```

Build Android APK:

```bash
flutter build apk
```

## Important Notes

- Keep the laptop database server running while employees use the app.
- Keep the Flutter web server running while employees access the browser link.
- If the laptop server is off, the app can still keep local/offline data on that device.
- For best multi-device use, start the laptop server first, then start the Flutter web app.
- The server page on port `9090` is only the API/database status page. The real shop app opens on the Flutter web port, usually `8080`.

## License

Add your preferred license before publishing this project publicly.
