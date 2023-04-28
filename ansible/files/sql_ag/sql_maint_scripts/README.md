SQL Server Backup, Integrity Check, and Index and Statistics Maintenance
=========================================================================

The SQL Server Maintenance Solution comprises scripts for running backups, integrity checks, and index and statistics maintenance on all editions of Microsoft SQL Server 2008, SQL Server 2008 R2, SQL Server 2012, SQL Server 2014, SQL Server 2016, SQL Server 2017, and SQL Server 2019. 

The solution is based on stored procedures. The solution has been designed for the most mission-critical environments, and it is used in many organizations around the world.

DBMaint.sql script creates all the objects and jobs that you need.
  
    SQL Server Maintenance Solution:
              •	DatabaseBackup: SQL Server Backup
              •	DatabaseIntegrityCheck: SQL Server Integrity Check
              •	IndexOptimize: SQL Server Index and Statistics Maintenance


DB Maintenance Procedure Plan
================================

    •	Ola Hallengren maintenance solution.
    •	Separate database - “DBADB” to contain
          >	All maintenance stored procedures.
          >	CommandLog table to keep track of maintenance activity.
          >	SQL Agent jobs for IndexRebuild, UpdateStats, DBCC & Clean-up ( Except for Azure SQL Database )
    •	Suitable for DBaaS and Cloud.
    •	Separate Index rebuild and Update stats.
    •	Avoid killing of update stats for Index rebuild.
    •	New database level options for optimal update stats.
    •	Faster Database Integrity Checks.
    •	More insight into SQL using Setup Performance Counters.

Index Rebuild
==============

    •	Ola Hallengren IndexOptimize procedure
    •	Separate job does only Index rebuild/reorg
    •	TimeLimit as per application maintenance window.
    •	LogToTable = Y, to keep track of index rebuild
    •	On completion, will kick “DBMaint – UpdateStats” job
    •	Min PageCount > 1000 for rebuild
    •	Schedule to be decided.
    •	Job will run through maintenance window


Stats Update
============

    •	Runs as a separate job after Index Rebuild.
    •	Non-intrusive and less resource intensive.
    •	Updates COLUMN stats only.
    •	@StatisticsModificationLevel= '5’ 
          >	update stats when 5% of the rows are changed. Tweak the threshold accordingly.
    •	@OnlyModifiedStatistics = 'Y’  
          >	***Updatestats even when 1 row is changed. Ok for small databases.  
          >	Problematic and wasteful CPU/IO for medium to big databases 
          >	Instead use @StatisticsModificationLevel with Lower threshold say 1%.
    •	@StatisticsSample : [SAMPLE | FULLSCAN] 
    •	@LogToTable = Y : To track the stats updated.
    •	Enable Auto Update Statistics along with Auto Update Statistics Asynchronously at database level


Database Integrity Checks
==========================

    •	To prevent database corruption.
    •	Lesser and important checks.
    •	Weekly DBCC for large database, daily for small to medium sized database.
    •	Covers torn pages & common hardware issues.
    •	Less CPU & IO intensive with PHYSICAL_ONLY


CleanUp
=======

    •	Separate cleanup job
    •	CommandLog cleanup – table that tracks maintenance activity
    •	Backup history cleanup – 
          >	dbo.sp_delete_backuphistory
          >	More 30 days
    •	Purge SQL Agent history -  more than 30 days
    •	Delete data collector set file after 30 days


Scheduling time for DB Jobs
===========================

    •	CreateDailyIndexOptSchedForIndexOpt.sql
    •	CreateMonthySundaySchedForCleanup.sql
    •	CreateWeeklySundaySchedForDBCC.sql


Resize TempDB Volume
===========================

    •	MoveTempDB.ps1
    •	MoveTempDB.sql


Test Failover
===========================

    •	TestAlwaysOnAG.ps1
