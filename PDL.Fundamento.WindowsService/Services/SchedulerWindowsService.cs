using Cronos;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using PDL.FundaMento.Interface.Interface;

namespace PDL.Fundamento.WindowsService.Services
{
    public class SchedulerWindowsService : BackgroundService
    {
        private readonly ILogger<SchedulerWindowsService> _logger;
        private readonly CronExpression PreDueData = CronExpression.Parse("*/2 * * * *");
        private readonly CronExpression PostDueData = CronExpression.Parse("*/4 * * * *");
        private readonly CronExpression EMICollectedData = CronExpression.Parse("*/6 * * * *");
        private readonly CronExpression OnboardingData = CronExpression.Parse("*/8 * * * *");
        private readonly CronExpression sendPreDueData = CronExpression.Parse("*/10 * * * *");
        private readonly CronExpression sendPostDueData = CronExpression.Parse("*/12 * * * *");
        private readonly CronExpression sendEMICollectedData = CronExpression.Parse("*/14 * * * *");
        private readonly CronExpression sendOnboardingData = CronExpression.Parse("*/16 * * * *");

        private readonly ISendPredue _service;
        private readonly IConfiguration _config;
        private readonly IServiceProvider _serviceProvider;

        public SchedulerWindowsService(
            ILogger<SchedulerWindowsService> logger, 
            ISendPredue service, 
            IConfiguration config,
            IServiceProvider serviceProvider)
        {
            _logger = logger;
            _service = service;
            _config = config;
            _serviceProvider = serviceProvider;
        }

        public override async Task StartAsync(CancellationToken cancellationToken)
        {
            _logger.LogInformation("PDL Fundamento Scheduler Windows Service is starting...");
            _logger.LogInformation("Service started at: {time}", DateTimeOffset.Now);
            await base.StartAsync(cancellationToken);
        }

        public override async Task StopAsync(CancellationToken cancellationToken)
        {
            _logger.LogInformation("PDL Fundamento Scheduler Windows Service is stopping...");
            _logger.LogInformation("Service stopped at: {time}", DateTimeOffset.Now);
            await base.StopAsync(cancellationToken);
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("PDL Fundamento Scheduler Windows Service Started");

            try
            {
                while (!stoppingToken.IsCancellationRequested)
                {
                    var now = DateTime.UtcNow;

                    await RunJob(PreDueData, now, "PreDueData", stoppingToken);
                    await RunJob(PostDueData, now, "PostDueData", stoppingToken);
                    await RunJob(EMICollectedData, now, "EMICollectedData", stoppingToken);
                    await RunJob(OnboardingData, now, "OnboardingData", stoppingToken);
                    await RunJob(sendPreDueData, now, "sendPreDueData", stoppingToken);
                    await RunJob(sendPostDueData, now, "sendPostDueData", stoppingToken);
                    await RunJob(sendEMICollectedData, now, "sendEMICollectedData", stoppingToken);
                    await RunJob(sendOnboardingData, now, "sendOnboardingData", stoppingToken);

                    await Task.Delay(1000, stoppingToken);
                }
            }
            catch (OperationCanceledException)
            {
                _logger.LogInformation("Scheduler Windows Service was cancelled");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "An error occurred in the Scheduler Windows Service");
                throw;
            }

            _logger.LogInformation("PDL Fundamento Scheduler Windows Service Stopped");
        }

        private async Task RunJob(CronExpression cron, DateTime now, string jobName, CancellationToken token)
        {
            try
            {
                DateTime? next = cron.GetNextOccurrence(now);

                if (!next.HasValue || (next.Value - now).TotalSeconds >= 1)
                    return;

                _logger.LogInformation($"{jobName} triggered at {DateTime.Now}");
                string WebhookURL = _config["WebhookAPI:WebhookUrl"];

                using var scope = _serviceProvider.CreateScope();
                var scopedService = scope.ServiceProvider.GetRequiredService<ISendPredue>();

                switch (jobName)
                {
                    case "PreDueData":
                        await scopedService.SendEMIPreDueData(token);
                        break;
                    case "PostDueData":
                        await scopedService.SendEMIPostDueData(token);
                        break;
                    case "EMICollectedData":
                        await scopedService.SendEMICollectedData("EMICollectedData", token);
                        break;
                    case "OnboardingData":
                        await scopedService.SendOnboardingData("Onboarding", token);
                        break;
                    case "sendPreDueData":
                        await scopedService.SendPreDueData("sendPreDue", WebhookURL, token);
                        break;
                    case "sendPostDueData":
                        await scopedService.SendPostDueData("sendPostDue", WebhookURL, token);
                        break;
                    case "sendEMICollectedData":
                        await scopedService.SendEMICollected("sendEMICollected", WebhookURL, token);
                        break;
                    case "sendOnboardingData":
                        await scopedService.SendOnboarding("sendOnboarding", WebhookURL, token);
                        break;
                    default:
                        _logger.LogWarning($"Unknown job: {jobName}");
                        break;
                }

                _logger.LogInformation($"{jobName} completed successfully at {DateTime.Now}");
            }
            catch (OperationCanceledException)
            {
                _logger.LogWarning($"{jobName} was cancelled.");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"{jobName} failed with error: {ex.Message}");
            }
        }
    }
}
