# PDL Fundamento Windows Service

This is a complete Windows Service implementation of the PDL Fundamento Scheduler that processes EMI data and sends notifications based on cron schedules.

## 🚀 Features

- **Windows Service Integration**: Runs as a proper Windows Service with automatic startup
- **Event Log Integration**: Logs to Windows Event Log for monitoring
- **Cron-based Scheduling**: Uses Cronos library for precise scheduling
- **Dependency Injection**: Proper DI container setup for services
- **Error Handling**: Comprehensive error handling and logging
- **Graceful Shutdown**: Proper service lifecycle management

## 📁 Project Structure

```
PDL.Fundamento.WindowsService/
├── Services/
│   ├── SchedulerWindowsService.cs    # Main service implementation
│   └── SendPredueService.cs          # Business logic service
├── Models/
│   └── EMIDueVM.cs                   # Data models
├── Interfaces/
│   └── ISendPredue.cs                # Service interface
├── Scripts/
│   ├── install-service.bat           # Service installation script
│   ├── uninstall-service.bat         # Service uninstallation script
│   ├── start-service.bat             # Service start script
│   └── stop-service.bat              # Service stop script
├── Program.cs                        # Application entry point
├── appsettings.json                  # Configuration file
└── PDL.Fundamento.WindowsService.csproj
```

## ⚙️ Configuration

Update the `appsettings.json` file with your database connection string and webhook URL:

```json
{
  "ConnectionStrings": {
    "PaisaloConnection": "Server=your-server;Database=your-database;Trusted_Connection=true;TrustServerCertificate=true;"
  },
  "WebhookAPI": {
    "WebhookUrl": "https://your-webhook-url.com/api/webhook"
  }
}
```

## 📅 Scheduled Jobs

The service runs the following jobs with their respective cron schedules:

- **PreDueData**: Every 2 minutes (`*/2 * * * *`)
- **PostDueData**: Every 4 minutes (`*/4 * * * *`)
- **EMICollectedData**: Every 6 minutes (`*/6 * * * *`)
- **OnboardingData**: Every 8 minutes (`*/8 * * * *`)
- **sendPreDueData**: Every 10 minutes (`*/10 * * * *`)
- **sendPostDueData**: Every 12 minutes (`*/12 * * * *`)
- **sendEMICollectedData**: Every 14 minutes (`*/14 * * * *`)
- **sendOnboardingData**: Every 16 minutes (`*/16 * * * *`)

## 🛠️ Installation and Deployment

### 1. Build the Project

```bash
dotnet build --configuration Release
```

### 2. Publish the Application

```bash
dotnet publish --configuration Release --output ./publish
```

### 3. Install as Windows Service

Run the installation script as Administrator:

```bash
cd publish
Scripts\install-service.bat
```

### 4. Service Management

- **Start Service**: Run `Scripts\start-service.bat` as Administrator
- **Stop Service**: Run `Scripts\stop-service.bat` as Administrator
- **Uninstall Service**: Run `Scripts\uninstall-service.bat` as Administrator

## 📊 Monitoring

### Event Log

The service logs to the Windows Event Log under:
- **Source**: PDL Fundamento Scheduler Service
- **Log**: Application

You can view logs using:
- Event Viewer (eventvwr.msc)
- PowerShell: `Get-EventLog -LogName Application -Source "PDL Fundamento Scheduler Service"`

### Service Status

Monitor the service status through:
- Services.msc (Windows Services Manager)
- Task Manager > Services tab
- PowerShell: `Get-Service "PDL Fundamento Scheduler Service"`

## 🔧 Development

### Running in Development

For development and testing, you can run the service as a console application:

```bash
dotnet run --environment Development
```

### Debugging

The service includes comprehensive logging. Set the log level to `Debug` in `appsettings.Development.json` for detailed logging during development.

## 📦 Dependencies

- **.NET 8.0**: Target framework
- **Cronos**: Cron expression parsing and scheduling
- **Microsoft.Extensions.Hosting.WindowsServices**: Windows Service integration
- **Microsoft.Extensions.Logging.EventLog**: Event Log integration
- **System.Data.SqlClient**: SQL Server connectivity

## 🛡️ Error Handling

The service includes robust error handling:
- Individual job failures don't stop the entire service
- All exceptions are logged to Event Log
- Service continues running even if individual jobs fail
- Graceful shutdown on service stop requests

## 🔒 Security Considerations

- Run the service with appropriate Windows service account permissions
- Ensure database connection strings are properly secured
- Consider using Windows Credential Manager for sensitive configuration
- Regularly monitor Event Logs for any security-related events

## 🚨 Troubleshooting

### Common Issues

1. **Service won't start**: Check Event Log for detailed error messages
2. **Database connection issues**: Verify connection string and permissions
3. **Permission errors**: Ensure service account has necessary permissions
4. **Cron schedule issues**: Verify cron expressions are valid

### Logs Location

- **Event Log**: Windows Event Viewer > Application Log
- **Console Output**: Only available when running in development mode

## 📞 Support

For issues and support, check the Event Log for detailed error messages and stack traces.

## 🔄 Key Differences from Worker Service

This Windows Service implementation provides several advantages over the original worker service:

1. **Native Windows Integration**: Proper Windows Service lifecycle management
2. **Event Log Integration**: Built-in logging to Windows Event Log
3. **Service Management**: Easy start/stop/restart through Windows Services
4. **Automatic Startup**: Configurable to start automatically with Windows
5. **Better Error Handling**: Improved error isolation and recovery
6. **Production Ready**: Designed for production deployment and monitoring

## 🚀 Quick Start

1. Clone the repository
2. Update `appsettings.json` with your configuration
3. Build and publish the project
4. Run the installation script as Administrator
5. Monitor through Event Viewer and Services Manager

Your PDL Fundamento Scheduler is now running as a proper Windows Service! 🎉
