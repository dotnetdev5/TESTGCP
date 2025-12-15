using PDL.FundaMento.Entity.Models;

namespace PDL.FundaMento.Interface.Interface
{
    public interface ISendPredue
    {
        Task<List<EMIDueVM>> SendEMIPreDueData(CancellationToken token);
        Task SendEMIPostDueData(CancellationToken token);
        Task SendEMICollectedData(string type, CancellationToken token);
        Task SendOnboardingData(string type, CancellationToken token);
        Task SendPreDueData(string type, string webhookUrl, CancellationToken token);
        Task SendPostDueData(string type, string webhookUrl, CancellationToken token);
        Task SendEMICollected(string type, string webhookUrl, CancellationToken token);
        Task SendOnboarding(string type, string webhookUrl, CancellationToken token);
    }
}
