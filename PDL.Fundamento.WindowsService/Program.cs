using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.EventLog;
using PDL.Fundamento.WindowsService.Services;
using PDL.FundaMento.Interface.Interface;

namespace PDL.Fundamento.WindowsService
{
    public class Program
    {
        public static async Task Main(string[] args)
        {
            var builder = Host.CreateApplicationBuilder(args);

            // Configure Windows Service
            builder.Services.AddWindowsService(options =>
            {
                options.ServiceName = "PDL Fundamento Scheduler Service";
            });

            // Configure logging for Windows Service
            builder.Services.AddLogging(configure =>
            {
                configure.AddConsole();
                configure.AddEventLog(new EventLogSettings()
                {
                    SourceName = "PDL Fundamento Scheduler Service",
                    LogName = "Application"
                });
            });

            // Register your services
            builder.Services.AddScoped<ISendPredue, SendPredueService>();
            
            // Register the main worker service
            builder.Services.AddHostedService<SchedulerWindowsService>();

            var host = builder.Build();

            try
            {
                await host.RunAsync();
            }
            catch (Exception ex)
            {
                var logger = host.Services.GetRequiredService<ILogger<Program>>();
                logger.LogCritical(ex, "Application terminated unexpectedly");
                throw;
            }
        }
    }
}
