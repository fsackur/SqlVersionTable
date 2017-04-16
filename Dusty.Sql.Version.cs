namespace Dusty.Sql
{
    public enum SqlServerRelease
    {
        SqlvNext = 1400,
        Sql2016 = 1300,
        Sql2014 = 1200,
        Sql2012 = 1100,
        Sql2008R2 = 1050,
        Sql2008 = 1000,
        Sql2005 = 900,
        Sql2000 = 800,
        Sql7 = 700
    }

    public enum SqlUpdateType
    {
        CTP,
        RC,
        RTM,
        GDR,
        SP,
        CU,
        Hotfix,
        Update
    }

    public class SqlServerBuild
    {
        public System.Version Version { get; set; }
        public System.Version SqlservrExeVersion { get; set; }
        public System.Version FileVersion { get; set; }
        public string Q { get; set; }
        public string KB { get; set; }
        public string Description { get; set; }
        public System.DateTime ReleaseDate { get; set; }
        public System.Uri Link { get; set; }
        public Dusty.Sql.SqlServerRelease Release { get; set; }
        public Dusty.Sql.SqlUpdateType UpdateType { get; set; }
    }
}
