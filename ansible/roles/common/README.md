# common

This role will prepare all the servers with the correct directories and permissions. It will also mount the additioanl volumes and initalise them.

## Table of content

- [Default Variables](#default-variables)
- [Tasks](#tasks)
- [Dependencies](#dependencies)
- [Requirements](#requirements)

---

## Default Variables

None

## Tasks

- 00-CreateDirectory
- 10-CopyScripts
- 20-DiskMount

## Dependencies

None

## Requirements

Requires servers to be Domain joined since a SQL service account is used to execute WinRM.
