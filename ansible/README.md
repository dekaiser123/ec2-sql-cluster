# Ansible

This ansible code is to orchestrate the configration of MS SQL AG cluster.

## Requirements

- Ansible >= 5.10.0
- Ansible Core >= 2.12.8
- pywinrm >= 0.4.3
- AWS Tools >= 4.1.104

This also includes all other depedent packages required for the above.

## Group Variables

| Name  | Default | Description |
|-------|---------|-------------|
| `ad_srv_user` | dynamic | SQL Service account |
| `ad_srv_pwd` | dynamic | SQL Service account password |
| `localAccount` | dynamic | SMC name retrieved from SSM |
| `cluWitness` | dynamic | FSx file witness |
| `s3Bucket` | dynamic | S3 app bucket |
| `HOST_COUNT` | dynamic | number of nodes |

All group variables have their values passed from the `sql_host.ps1` script.

## Playbooks

- newbuild
- rebuild
- destroy (to fix)
- patch (to do)

## Folder structure

```cmd
ansible
├───[files] Scripts used by Ansible roles
└──────[cluster_wfc]
└──────[common]
└──────[destroy_ag]
└──────[sql_ag]
└─────────[sql_maint_scripts] DBA sql scripts
├───[group_vars]
└───[roles] Ansible roles
└──────[cluster_wfc]
└─────────[tasks]
└──────[common]
└─────────[tasks]
└──────[destroy_ag]
└─────────[tasks]
└──────[sql_ag]
└─────────[tasks]
└─────────[vars]
```

Files subfolders must be the same name as the corresponding role name under the roles folder.

## Dependencies

SQL servers provisioned with WinRM enabled and it's respective secure port 5986 opened.

## Manually Test an Ansible Playbook 

On a linux machine (buildagent/dev env) create ansible inventory 

<details><summary>ansible inventory </summary>

example create file "app_hosts"
```
[APP_SVRNODE]
<Hostname> ansible_host=<IP> ansible_user=<Service Account> ansible_password=""
[APP_SVRNODE:vars]
ansible_port=5986
ansible_become=false
ansible_connection=winrm
ansible_winrm_server_cert_validation=ignore
ansible_winrm_transport=ntlm
ansible_shell_type=powershell
ansible_shell_executable=None
```
</details>

### How to run?

To run a playbook

```
ansible-playbook -i app_hosts newbuild.yml -e pass="${Password}"
```

To run a specific role, change to the directory of the role folder

```
ansible-playbook -i app_hosts main.yml -e pass="${Password}"
```

## Reference

[Ansible Documentation](https://docs.ansible.com/ansible/latest/index.html)
