using System;
using System.IO;
using System.IO.Compression;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Data;
using OfficeOpenXml;


namespace RBDataCollector
{
    class Program
    {
        static void Main(string[] args)
        {
            using (SqlConnection conn = new SqlConnection())
            {
                var exePath = System.AppDomain.CurrentDomain.BaseDirectory;
                string logFile = exePath + @"\Output\log\LogFile-" + DateTime.Now.ToString("yyyyMdd-HHmmss") + ".txt";
                //var StartupPath = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location); // AMc said use this to get the directory (do this later)
                //Path.GetFileName(file); // rich.exe from c:\users\rich.exe
                //Path.GetFileNameWithoutExtension(file); // rich from c:\users\rich.exe
                var UseIntenseMode = "n";

                Console.WriteLine("Use this data collector to gather SQL Server performance metrics");
                Console.WriteLine("");
                Console.WriteLine("Here's some guidelines when running this tool;");
                Console.WriteLine("");
                Console.WriteLine("'Server Name' is the name of the host machine where SQL is installed (required)");
                Console.WriteLine("'Instance Name' is the SQL instance, leave blank for default instance");
                Console.WriteLine("'Database Name' is to focus on the problem database specifically (required)");
                Console.WriteLine("'Intensive Mode' runs additional scripts, use 'N' unless you need more info");
                Console.WriteLine("'Use Windows Credentials' only use 'N' to enter username/password manually");
                Console.WriteLine("--------------------------------------------------------------------------------");

                bool hasConnected = false;
                while (!hasConnected)
                {
                    var UserInputs = new userParameters();
                    UserInputs.ServerName = Util.Console.Ask("Server Name: ");
                    File.AppendAllText(logFile, DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + ": Server Name: " + UserInputs.ServerName + Environment.NewLine);
                    UserInputs.InstanceName = Util.Console.Ask("Instance Name: ");
                    System.IO.File.AppendAllText(logFile, DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + ": Instance Name: " + UserInputs.InstanceName + Environment.NewLine);
                    UserInputs.DatabaseName = Util.Console.Ask("Database Name: ");
                    System.IO.File.AppendAllText(logFile, DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + ": Database Name: " + UserInputs.DatabaseName + Environment.NewLine);

                    if (UserInputs.InstanceName != "")
                    {
                        UserInputs.ServerName = UserInputs.ServerName + "\\" + UserInputs.InstanceName;
                    }

                    bool isIntenseMode = true;
                    while (isIntenseMode)
                    {
                        UserInputs.IntensiveMode = Util.Console.Ask("Run intensive mode? (y/n): ").ToLower();
                        if (UserInputs.IntensiveMode == "y")
                        {
                            isIntenseMode = false;
                            UseIntenseMode = "y";
                            System.IO.File.AppendAllText(logFile, DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + ": Use Intensive Mode: " + UserInputs.IntensiveMode + Environment.NewLine);
                        }
                        if (UserInputs.IntensiveMode == "n")
                        {
                            isIntenseMode = false;
                            UseIntenseMode = "n";
                            System.IO.File.AppendAllText(logFile, DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + ": Use Intensive Mode: " + UserInputs.IntensiveMode + Environment.NewLine);
                        }

                    }

                    bool wincredbool = true;
                    while (wincredbool)
                    {
                        UserInputs.UseWindowsCredentials = Util.Console.Ask("Connect Using Windows Credentials? (y/n): ").ToLower();
                        if (UserInputs.UseWindowsCredentials == "y" || UserInputs.UseWindowsCredentials == "n")
                        {
                            wincredbool = false;
                            System.IO.File.AppendAllText(logFile, DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + ": Use Windows Credentials: " + UserInputs.UseWindowsCredentials + Environment.NewLine);
                        }

                    }

                    try
                    {
                        Console.WriteLine(DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + ": Attempting Database Connection");
                        System.IO.File.AppendAllText(logFile, DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + ": Attempting Database Connection" + Environment.NewLine);
                        if (UserInputs.UseWindowsCredentials == "y")
                        {
                            conn.ConnectionString = string.Format("Server={0};Database={1};Integrated Security=SSPI;", UserInputs.ServerName, UserInputs.DatabaseName);
                            string userName = System.Security.Principal.WindowsIdentity.GetCurrent().Name;
                            System.IO.File.AppendAllText(logFile, DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + ": Connecting As: " + userName + Environment.NewLine);
                        }
                        else
                        {
                            UserInputs.DatabaseUsername = Util.Console.Ask("Username: ");
                            System.IO.File.AppendAllText(logFile, DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + ": Connecting As: " + UserInputs.DatabaseUsername + Environment.NewLine);
                            UserInputs.DatabasePassword = Util.Console.Ask("Password: ");
                            conn.ConnectionString = string.Format("Server={0}; Database={1}; User id={2}; Password={3};",
                                UserInputs.ServerName, UserInputs.DatabaseName, UserInputs.DatabaseUsername, UserInputs.DatabasePassword);
                        }
                        conn.Open();
                        hasConnected = true;
                        Console.WriteLine(DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + ": Database Connection Successful");
                        System.IO.File.AppendAllText(logFile, DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + ": Database Connection Successful" + Environment.NewLine);
                    }
                    catch (Exception e)
                    {

                        Console.WriteLine(DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + ": Database Connection Failed, please try again");
                        System.IO.File.AppendAllText(logFile, DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + " : " + e.ToString() + Environment.NewLine);
                    }


                }

                List<runnableScripts> scriptlist = new List<runnableScripts>();
                scriptlist.Add(new runnableScripts("01_instance_details.sql", exePath + @"\Scripts\01_instance_details.sql", "Environment", 7, 2));
                scriptlist.Add(new runnableScripts("02_installed_instances.sql", exePath + @"\Scripts\02_installed_instances.sql", "Environment", 7, 5));
                scriptlist.Add(new runnableScripts("03_Disk_Speed_Check.sql", exePath + @"\Scripts\03_Disk_Speed_Check.sql", "Disk Speed", 6, 2));
                scriptlist.Add(new runnableScripts("04_CPU_Utilisation.sql", exePath + @"\Scripts\04_CPU_Utilisation.sql", "Environment", 51, 2));
                scriptlist.Add(new runnableScripts("11_Blitz.sql", exePath + @"\Scripts\11_Blitz.sql", "Blitz Results", 6, 2));
                scriptlist.Add(new runnableScripts("12_sp_whoisactive.sql", exePath + @"\Scripts\12_sp_whoisactive.sql", "WhoIsActive", 6, 2));
                scriptlist.Add(new runnableScripts("21_waitstats_since_last_clear.sql", exePath + @"\Scripts\21_waitstats_since_last_clear.sql", "Waitstats", 6, 2));
                scriptlist.Add(new runnableScripts("23_waitstats_last_30_seconds.sql", exePath + @"\Scripts\23_waitstats_last_30_seconds.sql", "Waitstats", 36, 2));
                scriptlist.Add(new runnableScripts("40_BlitzIndex_Mode_0.sql", exePath + @"\Scripts\40_BlitzIndex_Mode_0.sql", "BlitzIndex Mode 0", 6, 2));
                scriptlist.Add(new runnableScripts("44_BlitzIndex_Mode_4.sql", exePath + @"\Scripts\44_BlitzIndex_Mode_4.sql", "BlitzIndex Mode 4", 6, 2));
                scriptlist.Add(new runnableScripts("50_memory_perf_counters.sql", exePath + @"\Scripts\50_memory_perf_counters.sql", "Memory", 6, 2));
                scriptlist.Add(new runnableScripts("51_memory_buffer_usage_by_db.sql", exePath + @"\Scripts\51_memory_buffer_usage_by_db.sql", "Memory by DB", 6, 2));
                scriptlist.Add(new runnableScripts("53_memory_plan_cache.sql", exePath + @"\Scripts\53_memory_plan_cache.sql", "Memory", 32, 2));
                scriptlist.Add(new runnableScripts("60_perf_counters.sql", exePath + @"\Scripts\60_perf_counters.sql", "Perf Counters", 6, 2));
                scriptlist.Add(new runnableScripts("81_BlitzCache_CPU.sql", exePath + @"\Scripts\81_BlitzCache_CPU.sql", "BlitzCache", 5, 2));
                scriptlist.Add(new runnableScripts("82_BlitzCache_Reads.sql", exePath + @"\Scripts\82_BlitzCache_Reads.sql", "BlitzCache", 18, 2));
                scriptlist.Add(new runnableScripts("83_BlitzCache_XPM.sql", exePath + @"\Scripts\83_BlitzCache_XPM.sql", "BlitzCache", 31, 2));
                scriptlist.Add(new runnableScripts("84_BlitzCache_Duration.sql", exePath + @"\Scripts\84_BlitzCache_Duration.sql", "BlitzCache", 44, 2));

                if (UseIntenseMode == "y")
                {
                    scriptlist.Add(new runnableScripts("42_BlitzIndex_Mode_2.sql", exePath + @"\Scripts\42_BlitzIndex_Mode_2.sql", "BlitzIndex Mode 2", 6, 2));
                    scriptlist.Add(new runnableScripts("52_memory_buffer_usage_by_db_numa.sql", exePath + @"\Scripts\52_memory_buffer_usage_by_db_numa.sql", "Memory by DB", 6, 8));
                    scriptlist.Add(new runnableScripts("24_deadlocks.sql", exePath + @"\Scripts\24_deadlocks.sql", "Deadlocks", 6, 2));
                    scriptlist.Add(new runnableScripts("24_deadlocks_2.sql", exePath + @"\Scripts\24_deadlocks_2.sql", "Deadlocks 2", 6, 2));
                }

                try
                {
                    string excelDocument = exePath + @"\OutputTemplate.xlsx";
                    var excelTemplate = new FileInfo(excelDocument);

                    using (ExcelPackage p = new ExcelPackage(excelTemplate))
                    {
                        int row = 0;
                        while (row < scriptlist.Count)
                        {
                            Console.WriteLine(DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + ": Running script " + scriptlist[row].FileName);
                            System.IO.File.AppendAllText(logFile, DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + " : Running Script " + scriptlist[row].FileName + Environment.NewLine);
                            try
                            {
                                string scriptPath = File.ReadAllText(scriptlist[row].FilePath);
                                SqlCommand cmd = new SqlCommand(scriptPath, conn);
                                cmd.CommandTimeout = 180;
                                ExcelWorksheet ws = p.Workbook.Worksheets[scriptlist[row].OutputSheet];
                                var table = new DataTable();
                                var startrow = scriptlist[row].StartRow;
                                var startcolumn = scriptlist[row].StartColumn;
                                var endrow = scriptlist[row].StartRow;
                                var endcolumn = scriptlist[row].StartColumn;

                                using (var da = new SqlDataAdapter(cmd))
                                {
                                    da.Fill(table);

                                    for (int i = 0; i < table.Rows.Count; i++)
                                    {
                                        for (int j = 0; j < table.Columns.Count; j++)
                                        {
                                            //try to parse to a number and insert, otherwise just insert.
                                            double value;
                                            if (double.TryParse(table.Rows[i][j].ToString(), out value))
                                            {
                                                ws.Cells[i + startrow, j + startcolumn].Value = value;
                                            }
                                            else
                                            {
                                                ws.Cells[i + startrow, j + startcolumn].Value = table.Rows[i][j];
                                            }

                                            //ws.Cells[i + startrow, j + startcolumn].Value = double.TryParse(table.Rows[i][j].ToString(), out value) ? value : table.Rows[i][j];


                                            endrow = i + startrow;
                                            endcolumn = j + startcolumn;

                                        }
                                    }

                                    //format this range as a table
                                    var range = ws.Cells[startrow - 1, startcolumn, endrow, endcolumn];
                                    var exceltable = ws.Tables.Add(range,"Table" + scriptlist[row].FileName);
                                    exceltable.TableStyle = OfficeOpenXml.Table.TableStyles.Medium1;
                                }
                                Console.WriteLine(DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + ": Finished Script " + scriptlist[row].FileName);
                                System.IO.File.AppendAllText(logFile, DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + " : Finished Script " + scriptlist[row].FileName + Environment.NewLine);
                                row++;
                            }
                            catch (SqlException te)
                            {
                                if (te.ErrorCode ==-2)
                                {
                                    Console.WriteLine(DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + ": " + scriptlist[row].FileName + " failed - Timeout");
                                    System.IO.File.AppendAllText(logFile, DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + " : " + te.ToString() + Environment.NewLine);
                                    row++;
                                }
                                Console.WriteLine(DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + ": " + scriptlist[row].FileName + " failed - SQL Exception");
                                System.IO.File.AppendAllText(logFile, DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + " : " + te.ToString() + Environment.NewLine);
                                row++;
                            }
                            catch (Exception ex)
                            {
                                Console.WriteLine(DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + ": " + scriptlist[row].FileName + " failed");
                                System.IO.File.AppendAllText(logFile, DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + " : " + ex.ToString() + Environment.NewLine);
                                row++;
                            }

                        }
                        string outputLocation = exePath + @"Output\Results-" + DateTime.Now.ToString("yyyyMdd-HHmmss") + ".xlsx";
                        var excelOutput = new FileInfo(outputLocation);
                        
                        p.SaveAs(excelOutput);
                    }
                }
                catch (Exception theException)
                {
                    Console.WriteLine("there was an error here, oops");
                    System.IO.File.AppendAllText(logFile, DateTime.Now.ToString("yyyy-M-dd-HH:mm:ss") + " : " + theException.ToString() + Environment.NewLine);
                }



                Console.WriteLine("                __     ");
                Console.WriteLine("               / _)    ");
                Console.WriteLine("      _.----._/ /      ");
                Console.WriteLine("     /         /       ");
                Console.WriteLine("  __/ (  | (  |        ");
                Console.WriteLine(" /__.-'|_|--|_|        ");
                Console.WriteLine(" Hey Look, It's Henry  ");
                Console.WriteLine(" That means we're done ");
                Console.WriteLine(" The output is here: " + exePath + @"Output\Results-" + DateTime.Now.ToString("yyyyMdd-HHmmss") + ".xlsx");
            }
        }
    }

    public class userParameters
    {
        public string ServerName;
        public string InstanceName;
        public string DatabaseName;
        public string UseWindowsCredentials;
        public string DatabaseUsername;
        public string DatabasePassword;
        public string IntensiveMode;
    }

    public class runnableScripts
    {
        public runnableScripts(string filename, string filepath, string outputSheet, int startRow, int startColumn)
        {
            this.FileName = filename;
            this.FilePath = filepath;
            this.OutputSheet = outputSheet;
            this.StartRow = startRow;
            this.StartColumn = startColumn;
        }
        public string FileName { private set; get; }
        public string FilePath { set; get; }
        public string OutputSheet { set; get; }
        public int StartRow { set; get; }
        public int StartColumn { set; get; }
    }
}