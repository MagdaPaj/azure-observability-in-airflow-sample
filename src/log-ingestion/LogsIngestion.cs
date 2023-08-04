using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using Azure;
using Azure.Identity;
using Azure.Monitor.Ingestion;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;

namespace Sample.Function
{
    public class LogsIngestion
    {
        [FunctionName("LogsIngestion")]
        public async Task Run([BlobTrigger("airflowlogscontainer/{name}.log", Connection = "airflowlogs_STORAGE")]Stream myBlob, string name, ILogger log)
        {
            log.LogInformation($"C# Blob trigger function starting processing blob\n Name:{name} \n Size: {myBlob.Length} Bytes");

            var endpoint = new Uri(GetEnvironmentVariable("DataCollectionEndpoint"));
            var ruleId = GetEnvironmentVariable("DataCollectionRuleId");
            var streamName = "Custom-AirflowLogs_CL";

            var credential = new DefaultAzureCredential();
            LogsIngestionClient client = new(endpoint, credential);

            DateTimeOffset currentTime = DateTimeOffset.UtcNow;

            var entries = new List<Object>();
            using var reader = new StreamReader(myBlob);

            while (!reader.EndOfStream)
            {
                string line = await reader.ReadLineAsync();
                log.LogInformation(line);
                entries.Add(
                    new {
                        Time = currentTime,
                        RawData = line,
                        Application = "LogsIngestionFunction"
                    }
                );
            }


            // Set concurrency and EventHandler in LogsUploadOptions
            LogsUploadOptions options = new LogsUploadOptions();
            options.MaxConcurrency = 10;
            options.UploadFailed += Options_UploadFailed;

            await client.UploadAsync(ruleId, streamName, entries);
        }

        private static string GetEnvironmentVariable(string name)
        {
            return System.Environment.GetEnvironmentVariable(name, EnvironmentVariableTarget.Process);
        }

        private Task Options_UploadFailed(LogsUploadFailedEventArgs e)
        {
            // Throw exception from EventHandler to stop Upload if there is a failure
            // 413 status is RequestTooLarge - don't throw here because other batches can successfully upload
            if ((e.Exception is RequestFailedException) && (((RequestFailedException)e.Exception).Status != 413))
                // log.LogInformation($"Total logs failed to upload: {e.FailedLogs.Count}");
                throw e.Exception;
            else
                return Task.CompletedTask;
        }
    }
}
