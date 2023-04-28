# cluster_wfc

This role will setup Windows Failover Cluster on set number of nodes.

## Table of content

- [Default Variables](#default-variables)
- [Tasks](#tasks)
- [Dependencies](#dependencies)
- [Requirements](#requirements)

---

## Default Variables

None

## Tasks

- 00-CopyScripts
- 10-Wsfc

## Dependencies

Upon conditions in `newbuild` playbook

## Requirements

Requires servers to be Domain joined since a SQL service account is used to create the cluster and to execute WinRM. Domain Join service account is used to prestage CNOs.
