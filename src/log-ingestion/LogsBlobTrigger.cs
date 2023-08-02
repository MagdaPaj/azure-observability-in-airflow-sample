using System.IO;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;

namespace Sample.Function
{
    public class LogsBlobTrigger
    {
        [FunctionName("LogsBlobTrigger")]
        public void Run([BlobTrigger("airflowlogscontainer/{name}.log", Connection = "airflowlogs2_STORAGE")]Stream myBlob, string name, ILogger log)
        {
            log.LogInformation($"C# Blob trigger function Processed blob\n Name:{name} \n Size: {myBlob.Length} Bytes");
        }
    }
}
