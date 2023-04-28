# sql_ag

This role will install MS SQL server across set number of nodes, create an SQL Availability Group and Listener.
It also configures the required firewall ports and perform failover test to check successful build.

## Table of content

- [Default Variables](#default-variables)
  - [sqldir](#sqldir)
  - [tempdb](#tempdb)
- [Tasks](#tasks)
- [Dependencies](#dependencies)
- [Requirements](#requirements)

---

## Default Variables

### sqldir

A list of SQL Directories from the SQL config file.

#### Example usage

```YAML
sqldir:
   - SQLBACKUPDIR
   - SQLUSERDBDIR
   - SQLUSERDBLOGDIR
```

### tempdb

Drive letter of where the tempDB is to stored

#### Example usage

```YAML
tempdb: '<driveletter>:\'
```

## Tasks

- 00-CopyScripts
- 01-prepare-instance
- 02-Sqlag-Win-Firewall
- 10-Sql-install
- 11-Sqlag (included upon condition)

## Dependencies

- common
- cluster_wfc

## Requirements

Requires servers to be Domain joined since a SQL service account is used for the SQL installation, configuration and to execute WinRM.
