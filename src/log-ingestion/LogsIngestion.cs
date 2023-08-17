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
        public async Task Run([BlobTrigger("logs/{name}.log", Connection = "LogsStorage")]Stream myBlob, string name, ILogger log)
        {
            log.LogInformation($"C# Blob trigger function starting processing blob\n Name: {name} \n Size: {myBlob.Length} Bytes");

            var endpoint = new Uri(GetEnvironmentVariable("DataCollectionEndpoint"));
            var ruleId = GetEnvironmentVariable("DataCollectionRuleId");
            var streamName = GetEnvironmentVariable("DataCollectionRuleStreamName");

            var credential = new DefaultAzureCredential();
            LogsIngestionClient client = new(endpoint, credential);

            var currentTime = DateTimeOffset.UtcNow;

            var entries = new List<Object>();
            using var reader = new StreamReader(myBlob);

            while (!reader.EndOfStream)
            {
                var line = await reader.ReadLineAsync().ConfigureAwait(false);
                log.LogInformation(line);
                entries.Add(
                    new
                    {
                        Time = currentTime,
                        RawData = line,
                        Application = "LogsIngestionFunction"
                    }
                );
            }

            try
            {
                await client.UploadAsync(ruleId, streamName, entries).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                log.LogError($"Error while uploading: {ex}");
                throw;
            }
        }

        private static string GetEnvironmentVariable(string name)
        {
            return System.Environment.GetEnvironmentVariable(name, EnvironmentVariableTarget.Process);
        }
    }
}
