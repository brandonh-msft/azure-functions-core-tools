﻿// Copyright (c) .NET Foundation. All rights reserved.
// Licensed under the MIT License. See LICENSE in the project root for license information.

using Xunit.Abstractions;

namespace Azure.Functions.Cli.TestFramework.Commands
{
    /// <summary>
    /// Represents the root context for the `func` command.
    /// </summary>
    public class FuncRootCommand(string funcPath, string testName, ITestOutputHelper log) : FuncCommand(log)
    {
        private readonly string _funcPath = funcPath;
        private readonly string _testName = testName;

        protected override CommandInfo CreateCommand(IEnumerable<string> args)
        {
            var arguments = args.ToList();

            if (WorkingDirectory is null)
            {
                throw new InvalidOperationException("Working Directory must be set");
            }

            var commandInfo = new CommandInfo()
            {
                FileName = _funcPath,
                Arguments = arguments,
                WorkingDirectory = WorkingDirectory,
                TestName = _testName,
            };

            return commandInfo;
        }
    }
}
