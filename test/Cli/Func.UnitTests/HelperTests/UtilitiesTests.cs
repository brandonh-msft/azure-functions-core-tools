// Copyright (c) .NET Foundation. All rights reserved.
// Licensed under the MIT License. See LICENSE in the project root for license information.

using Microsoft.Azure.WebJobs.Script.Configuration;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Xunit;

namespace Azure.Functions.Cli.UnitTests.HelperTests
{
    public class UtilitiesTests
    {
        [Theory]
        [InlineData(LogLevel.None)]
        [InlineData(LogLevel.Debug)]
        [InlineData(LogLevel.Information)]
        public void GetHostJsonDefaultLogLevel_Test(LogLevel expectedLogLevel)
        {
            var settings = new Dictionary<string, string>();
            settings.Add(ConfigurationPath.Combine(ConfigurationSectionNames.JobHost, "logging", "loglevel", "default"), expectedLogLevel.ToString());
            var testConfiguration = TestUtilities.CreateSetupWithConfiguration(settings);
            LogLevel actualLogLevel;
            bool result = Utilities.LogLevelExists(testConfiguration, Utilities.LogLevelDefaultSection, out actualLogLevel);
            Assert.Equal(actualLogLevel, expectedLogLevel);
        }

        [Theory]
        [InlineData("ExtensionBundle", true)]
        [InlineData("extensionBundle", false)]
        public void JobHostConfigSectionExists_Test(string section, bool expected)
        {
            var settings = new Dictionary<string, string>();
            if (expected)
            {
                settings.Add(ConfigurationPath.Combine(ConfigurationSectionNames.JobHost, "extensionBundle", "id"), "Microsoft.Azure.Functions.ExtensionBundle");
                settings.Add(ConfigurationPath.Combine(ConfigurationSectionNames.JobHost, "extensionBundle", "version"), "[2.*, 3.0.0)");
            }

            var testConfiguration = TestUtilities.CreateSetupWithConfiguration(settings);
            Assert.Equal(expected, Utilities.JobHostConfigSectionExists(testConfiguration, section));
        }

        [Theory]
        [InlineData("Function.Function1", LogLevel.None, true)]
        [InlineData("Function.Function1", LogLevel.Warning, true)]
        [InlineData("Function.Function1.User", LogLevel.Information, true)]
        [InlineData("Host.General", LogLevel.Information, false)]
        [InlineData("Host.Startup", LogLevel.Error, true)]
        [InlineData("Host.General", LogLevel.Warning, true)]
        public void DefaultLoggingFilter_Test(string inputCategory, LogLevel inputLogLevel, bool expected)
        {
            Assert.Equal(expected, Utilities.DefaultLoggingFilter(inputCategory, inputLogLevel, LogLevel.Information, LogLevel.Warning));
        }

        [Theory]
        [InlineData("Function.Function1", true)]
        [InlineData("Random", false)]
        [InlineData("Host.Startup", true)]
        [InlineData("Microsoft.Azure.WebJobs.TestLogger", true)]
        [InlineData("Microsoft.Azure.TestLogger", false)]
        public void IsSystemLogCategory_Test(string inputCategory, bool expected)
        {
            Assert.Equal(expected, Utilities.IsSystemLogCategory(inputCategory));
        }

        [Theory]
        [InlineData(true)]
        [InlineData(false)]
        public void Test_IsMinifiedVersion(bool expected)
        {
            var filePath = Path.Combine("artifactsconfig.json");
            string artifactsJsonContent = "{\"minifiedVersion\": " + expected.ToString().ToLower() + "}";
            File.WriteAllTextAsync(filePath, artifactsJsonContent).GetAwaiter().GetResult();

            bool output = Utilities.IsMinifiedVersion();

            File.Delete(filePath);
            Assert.Equal(expected, output);
        }
    }
}
