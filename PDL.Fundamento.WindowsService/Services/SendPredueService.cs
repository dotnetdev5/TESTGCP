using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using PDL.FundaMento.Entity.Models;
using PDL.FundaMento.Interface.Interface;
using System.Data;
using System.Data.SqlClient;

namespace PDL.Fundamento.WindowsService.Services
{
    public class SendPredueService : ISendPredue
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<SendPredueService> _logger;

        public SendPredueService(IConfiguration configuration, ILogger<SendPredueService> logger)
        {
            _configuration = configuration;
            _logger = logger;
        }

        public async Task<List<EMIDueVM>> SendEMIPreDueData(CancellationToken token)
        {
            try
            {
                _logger.LogInformation("Starting SendEMIPreDueData process");

                List<EMIDueVM> results = new List<EMIDueVM>();
                string type = "SendPreDue";
                List<SchedulerParameters> pram = await GetMethods(type, token);
                string[] methods = pram[0].Parameters.Split(',');
                await TruncateTable(token, type);

                foreach (var items in methods)
                {
                    int dayToDue = Convert.ToInt32(items);
                    var result = new List<EMIDueVM>();
                    DataTable dt = CreateDataTable();

                    using (SqlConnection con = new SqlConnection(_configuration.GetConnectionString("PaisaloConnection")))
                    using (SqlCommand cmd = new SqlCommand("Usp_GETEMIDueData", con))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.CommandTimeout = 0;
                        cmd.Parameters.AddWithValue("@DayToDue", dayToDue);

                        await con.OpenAsync(token);

                        using (SqlDataReader rdr = await cmd.ExecuteReaderAsync(token))
                        {
                            while (await rdr.ReadAsync(token))
                            {
                                var item = CreateEMIDueVM(rdr, dayToDue);
                                result.Add(item);
                                AddToDataTable(dt, item, rdr, dayToDue);
                            }
                        }
                    }

                    if (dayToDue == 0)
                    {
                        dt = FilterDataTableByCreator(dt);
                    }

                    await BulkInsertAsync(dt, "sendPreDue", token);
                    results.AddRange(result);
                }

                _logger.LogInformation($"SendEMIPreDueData completed successfully. Processed {results.Count} records");
                return results;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in SendEMIPreDueData");
                throw;
            }
        }

        // Placeholder implementations for other interface methods
        public async Task SendEMIPostDueData(CancellationToken token)
        {
            _logger.LogInformation("SendEMIPostDueData called");
            await Task.CompletedTask;
        }

        public async Task SendEMICollectedData(string type, CancellationToken token)
        {
            _logger.LogInformation($"SendEMICollectedData called with type: {type}");
            await Task.CompletedTask;
        }

        public async Task SendOnboardingData(string type, CancellationToken token)
        {
            _logger.LogInformation($"SendOnboardingData called with type: {type}");
            await Task.CompletedTask;
        }

        public async Task SendPreDueData(string type, string webhookUrl, CancellationToken token)
        {
            _logger.LogInformation($"SendPreDueData called with type: {type}, webhookUrl: {webhookUrl}");
            await Task.CompletedTask;
        }

        public async Task SendPostDueData(string type, string webhookUrl, CancellationToken token)
        {
            _logger.LogInformation($"SendPostDueData called with type: {type}, webhookUrl: {webhookUrl}");
            await Task.CompletedTask;
        }

        public async Task SendEMICollected(string type, string webhookUrl, CancellationToken token)
        {
            _logger.LogInformation($"SendEMICollected called with type: {type}, webhookUrl: {webhookUrl}");
            await Task.CompletedTask;
        }

        public async Task SendOnboarding(string type, string webhookUrl, CancellationToken token)
        {
            _logger.LogInformation($"SendOnboarding called with type: {type}, webhookUrl: {webhookUrl}");
            await Task.CompletedTask;
        }

        // Helper methods
        private DataTable CreateDataTable()
        {
            DataTable dt = new DataTable();
            dt.Columns.Add("ContactNumber", typeof(string));
            dt.Columns.Add("CustomerName", typeof(string));
            dt.Columns.Add("SmCode", typeof(string));
            dt.Columns.Add("LoanAmount", typeof(decimal));
            dt.Columns.Add("Amount", typeof(decimal));
            dt.Columns.Add("DueDate", typeof(DateTime));
            dt.Columns.Add("DisbursalDate", typeof(DateTime));
            dt.Columns.Add("StateName", typeof(string));
            dt.Columns.Add("Branch", typeof(string));
            dt.Columns.Add("Creator", typeof(string));
            dt.Columns.Add("LoanType", typeof(string));
            dt.Columns.Add("Bucket", typeof(string));
            dt.Columns.Add("DaysToDue", typeof(int));
            dt.Columns.Add("DateAdded", typeof(DateTime));
            return dt;
        }

        private EMIDueVM CreateEMIDueVM(SqlDataReader rdr, int dayToDue)
        {
            string creator = rdr["Creator"].ToString();
            DateTime dueDate = DateTime.TryParse(rdr["DueDate"].ToString(), out var dtDue) ? dtDue : DateTime.MinValue;
            
            int totalSubmitted = 0;
            var val = rdr["TotalSubmitted"];
            if (val != DBNull.Value && int.TryParse(val.ToString(), out int tmp))
                totalSubmitted = tmp;

            string bucket = totalSubmitted == 0 ? "femi_1" : "1";

            return new EMIDueVM
            {
                contactNumber = "91" + rdr["MobileNumber"].ToString(),
                metadata = new Metadata
                {
                    customer_name = rdr["CustomerName"].ToString(),
                    sm_code = rdr["SmCode"].ToString(),
                    loan_amount = rdr["LoanAmount"].ToString(),
                    amount = rdr["EmiAmount"].ToString(),
                    due_date = dueDate.ToString("dd-MMMM-yyyy"),
                    disbursal_date = DateTime.TryParse(rdr["DisbursmentDate"]?.ToString(), out var disb) ? disb.ToString("dd-MMMM-yyyy") : "",
                    state = rdr["State"].ToString(),
                    branch = rdr["BranchName"].ToString(),
                    creator = creator,
                    loan_type = rdr["LoanType"].ToString(),
                    bucket = bucket,
                    days_to_due = dayToDue.ToString(),
                    days_past_due = "",
                    dateadded = DateTime.Today.ToString("dd-MMMM-yyyy")
                }
            };
        }

        private void AddToDataTable(DataTable dt, EMIDueVM item, SqlDataReader rdr, int dayToDue)
        {
            DateTime dueDate = DateTime.TryParse(rdr["DueDate"].ToString(), out var dtDue) ? dtDue : DateTime.MinValue;
            
            dt.Rows.Add(
                item.contactNumber,
                item.metadata.customer_name,
                item.metadata.sm_code,
                Convert.ToDecimal(item.metadata.loan_amount),
                Convert.ToDecimal(item.metadata.amount),
                dueDate,
                string.IsNullOrEmpty(item.metadata.disbursal_date) ? DBNull.Value : Convert.ToDateTime(item.metadata.disbursal_date),
                item.metadata.state,
                item.metadata.branch,
                item.metadata.creator,
                item.metadata.loan_type,
                item.metadata.bucket,
                dayToDue,
                DateTime.Today
            );
        }

        private async Task<List<SchedulerParameters>> GetMethods(string type, CancellationToken token)
        {
            var parameters = new List<SchedulerParameters>();
            
            using (SqlConnection con = new SqlConnection(_configuration.GetConnectionString("PaisaloConnection")))
            using (SqlCommand cmd = new SqlCommand("Usp_GetSchedulerParameters", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@Type", type);

                await con.OpenAsync(token);

                using (SqlDataReader rdr = await cmd.ExecuteReaderAsync(token))
                {
                    while (await rdr.ReadAsync(token))
                    {
                        parameters.Add(new SchedulerParameters
                        {
                            Parameters = rdr["Parameters"].ToString()
                        });
                    }
                }
            }

            return parameters;
        }

        private async Task TruncateTable(CancellationToken token, string type)
        {
            using (SqlConnection con = new SqlConnection(_configuration.GetConnectionString("PaisaloConnection")))
            using (SqlCommand cmd = new SqlCommand("Usp_TruncateTable", con))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.AddWithValue("@Type", type);

                await con.OpenAsync(token);
                await cmd.ExecuteNonQueryAsync(token);
            }
        }

        private DataTable FilterDataTableByCreator(DataTable dt)
        {
            var filteredRows = dt.AsEnumerable()
                .Where(row => row.Field<string>("Creator").StartsWith("VH") ||
                             row.Field<string>("Creator").StartsWith("OH"));

            if (filteredRows.Any())
            {
                return filteredRows.CopyToDataTable();
            }

            return dt.Clone();
        }

        private async Task BulkInsertAsync(DataTable dataTable, string tableName, CancellationToken token)
        {
            using (SqlConnection con = new SqlConnection(_configuration.GetConnectionString("PaisaloConnection")))
            {
                await con.OpenAsync(token);

                using (SqlBulkCopy bulkCopy = new SqlBulkCopy(con))
                {
                    bulkCopy.DestinationTableName = tableName;
                    bulkCopy.BulkCopyTimeout = 0;

                    await bulkCopy.WriteToServerAsync(dataTable, token);
                }
            }
        }
    }
}
