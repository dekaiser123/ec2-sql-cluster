# destroy_ag

This role destroys the MS SQL AG. (This is not fully tested, use under your own risk)

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
- 01-remove-ag-cluster

## Dependencies

None

## Requirements

Requires servers to be Domain joined since a SQL service account is used remove the AG and to execute WinRM. Domain Join service account is used to remove CNOs.