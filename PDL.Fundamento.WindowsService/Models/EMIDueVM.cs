namespace PDL.FundaMento.Entity.Models
{
    public class EMIDueVM
    {
        public string contactNumber { get; set; } = string.Empty;
        public Metadata metadata { get; set; } = new Metadata();
    }

    public class Metadata
    {
        public string customer_name { get; set; } = string.Empty;
        public string sm_code { get; set; } = string.Empty;
        public string loan_amount { get; set; } = string.Empty;
        public string amount { get; set; } = string.Empty;
        public string due_date { get; set; } = string.Empty;
        public string disbursal_date { get; set; } = string.Empty;
        public string state { get; set; } = string.Empty;
        public string branch { get; set; } = string.Empty;
        public string creator { get; set; } = string.Empty;
        public string loan_type { get; set; } = string.Empty;
        public string bucket { get; set; } = string.Empty;
        public string days_to_due { get; set; } = string.Empty;
        public string days_past_due { get; set; } = string.Empty;
        public string dateadded { get; set; } = string.Empty;
    }

    public class SchedulerParameters
    {
        public string Parameters { get; set; } = string.Empty;
    }
}
