# hashicorp-vault-oss-ha
HashiCorp Vault Opensource HA

## Information about the servers deploying the lab

| Hostname | IP Address | OS | NTP Time Synchronization |
| :--- | :--- | :--- | :--- |
| vault-1.vault.local | 172.31.42.183 | Ubuntu 22.04 LTS | Sync |
| vault-2.vault.local | 172.31.34.167 | Ubuntu 22.04 LTS | Sync |
| vault-3.vault.local | 172.31.42.189 | Ubuntu 22.04 LTS | Sync |


## Step-by-step

### Setup basic (Perform on all node)
```
# hostnamectl set-hostname <HOSTNAME>

# echo -e "172.31.42.183 vault-1.vault.local\n172.31.34.167 vault-2.vault.local\n172.31.42.189 vault-3.vault.local" >> /etc/hosts

# wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# sudo apt update && sudo apt install vault
```

### Apply Vault config "/etc/vault.d/vault.hcl"
**Template file for "Disable TLS":**
```
cluster_addr  = "http://vault-1.vault.local:8201"
api_addr      = "http://vault-1.vault.local:8200"
disable_mlock = true
log_level = "trace"
disable_cache = true
cluster_name = "Test"

default_lease_ttl = "87600h"
max_lease_ttl = "87600h"

listener "tcp" {
  address            = "0.0.0.0:8200"
  tls_disable = true
}

ui = true

storage "raft" {
  path    = "/opt/vault/data"
  node_id = "1"

  retry_join {
    leader_api_addr         = "http://vault-1.vault.local:8200"
  }
  retry_join {
    leader_api_addr         = "http://vault-2.vault.local:8200"
  }
  retry_join {
    leader_api_addr         = "http://vault-3.vault.local:8200"
  }
}
```

**Template file for "Enable TLS":**
```
cluster_addr  = "https://vault-1.vault.local:8201"
api_addr      = "https://vault-1.vault.local:8200"
disable_mlock = true
log_level = "trace"
disable_cache = true
cluster_name = "Test"

default_lease_ttl = "87600h"
max_lease_ttl = "87600h"

listener "tcp" {
  address            = "0.0.0.0:8200"
  tls_disable = false
  tls_cert_file      = "/opt/vault/tls/vault-cert.pem"
  tls_key_file       = "/opt/vault/tls/vault-key.pem"
  tls_client_ca_file = "/opt/vault/tls/vault-ca.pem"
}

ui = true

storage "raft" {
  path    = "/opt/vault/data"
  node_id = "1"

  retry_join {
    leader_api_addr         = "https://vault-1.vault.local:8200"
    leader_ca_cert_file     = "/opt/vault/tls/vault-ca.pem"
    leader_client_cert_file = "/opt/vault/tls/vault-cert.pem"
    leader_client_key_file  = "/opt/vault/tls/vault-key.pem"
  }
  retry_join {
    leader_api_addr         = "https://vault-2.vault.local:8200"
    leader_ca_cert_file     = "/opt/vault/tls/vault-ca.pem"
    leader_client_cert_file = "/opt/vault/tls/vault-cert.pem"
    leader_client_key_file  = "/opt/vault/tls/vault-key.pem"
  }
  retry_join {
    leader_api_addr         = "https://vault-3.vault.local:8200"
    leader_ca_cert_file     = "/opt/vault/tls/vault-ca.pem"
    leader_client_cert_file = "/opt/vault/tls/vault-cert.pem"
    leader_client_key_file  = "/opt/vault/tls/vault-key.pem"
  }
}
```
>[!TIP]
> Before applying config Template File for "Enable TLS": MUST standardize the appropriate CA, Cert and Key files stored in "/opt/vault/tls" and assign appropriate permissions
```
# chown root:root /opt/vault/tls/vault-cert.pem /opt/vault/tls/vault-ca.pem

# chown root:vault /opt/vault/tls/vault-key.pem

# chmod 0644 /opt/vault/tls/vault-cert.pem /opt/vault/tls/vault-ca.pem

# chmod 0640 /opt/vault/tls/vault-key.pem
```

### Start and Enable service on all node
```
# systemctl enable vault

# systemctl start vault
```

### Bootrap cluster (Only perform on 1 node)
>[!NOTE]
> The information in this example is only valid for the duration of the lab. PLEASE do not reuse this information. "Unseal Key" and "Initial Root Token" are secret information that need to be stored carefully for use when restarting the service. Store them carefully and securely as possible to protect the secret information stored in the Vault cluster

**(Optinal) Only config Vault Cluster with TLS Enable (with Selfsign CA)**
```
root@vault-1:/etc/vault.d# export VAULT_CACERT=/opt/vault/tls/vault-ca.pem; echo "export VAULT_CACERT=/opt/vault/tls/vault-ca.pem" >> ~/.bashrc
```

**Bootrap Cluster Step-by-Step**
```
root@vault-1:/etc/vault.d# export VAULT_ADDR=http://vault-1.vault.local:8200; echo "export VAULT_ADDR=http://vault-1.vault.local:8200" >> ~/.bashrc
```

```
root@vault-1:/etc/vault.d# vault operator init

Unseal Key 1: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Unseal Key 2: YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY
Unseal Key 3: ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
Unseal Key 4: OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO
Unseal Key 5: KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK

Initial Root Token: xxxxxxxxxxxxxxxxx

Vault initialized with 5 key shares and a key threshold of 3. Please securely
distribute the key shares printed above. When the Vault is re-sealed,
restarted, or stopped, you must supply at least 3 of these keys to unseal it
before it can start servicing requests.

Vault does not store the generated root key. Without at least 3 keys to
reconstruct the root key, Vault will remain permanently sealed!

It is possible to generate new unseal keys, provided you have a quorum of
existing unseal keys shares. See "vault operator rekey" for more information.
```

```
root@vault-1:~# vault operator unseal
Unseal Key (will be hidden): <ENTER UNSEAL KEY>
```
>[!TIP]
> Default unseal policy is to enter 3 times and the entered Unseal keys cannot be duplicated

### Join other node and unseal with cluster credential
>[!TIP]
> Example perform for node vault-2.vault.local. Other notes perform similarly

**(Optinal) Only config Vault Cluster with TLS Enable (with Selfsign CA)**
```
export VAULT_CACERT=/opt/vault/tls/vault-ca.pem; echo "export VAULT_CACERT=/opt/vault/tls/vault-ca.pem" >> ~/.bashrc
```

```
export VAULT_ADDR=http://vault-2.vault.local:8200; echo "export VAULT_ADDR=http://vault-2.vault.local:8200" >> ~/.bashrc
```

```
root@vault-1:~# vault operator unseal
Unseal Key (will be hidden): <ENTER UNSEAL KEY>
```
>[!TIP]
> Default unseal policy is to enter 3 times and the entered Unseal keys cannot be duplicated

### Review cluster information
```
root@vault-1:~# vault status
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  false
Total Shares            5
Threshold               3
Version                 1.19.1
Build Date              2025-04-02T15:43:01Z
Storage Type            raft
Cluster Name            Test
Cluster ID              6da8a9d0-b6e5-760d-5496-95bc2a19deab
Removed From Cluster    false
HA Enabled              true
HA Cluster              https://vault-1.vault.local:8201
HA Mode                 active
Active Since            2025-04-16T04:33:38.02265637Z
Raft Committed Index    2736
Raft Applied Index      2736
```

```
root@vault-1:~# vault operator members
Host Name              API Address                        Cluster Address                     Active Node    Version    Upgrade Version    Redundancy Zone    Last Echo
---------              -----------                        ---------------                     -----------    -------    ---------------    ---------------    ---------
vault-1.vault.local    http://vault-1.vault.local:8200    https://vault-1.vault.local:8201    true           1.19.1     1.19.1             n/a                n/a
vault-2.vault.local    http://vault-2.vault.local:8200    https://vault-2.vault.local:8201    false          1.19.1     1.19.1             n/a                2025-04-16T04:35:03Z
vault-3.vault.local    http://vault-3.vault.local:8200    https://vault-3.vault.local:8201    false          1.19.1     1.19.1             n/a                2025-04-16T04:35:01Z
```

```
root@vault-1:/home/ubuntu# vault operator raft list-peers
Node    Address                     State       Voter
----    -------                     -----       -----
1       vault-1.vault.local:8201    leader      true
2       vault-2.vault.local:8201    follower    true
3       vault-3.vault.local:8201    follower    true
```

### (Optional) Enable Audit Log (Perform on all node)
```
# touch /var/log/vault_audit.json 

# chown vault:vault /var/log/vault_audit.json

# vault audit enable file file_path=/var/log/vault_audit.json

# vault audit list
Path     Type    Description
----     ----    -----------
file/    file    n/a
```

### Vault client connect using cli
```
# vault login
Token (will be hidden): <ACCESS_TOKEN>
```

### Enable secret kv-v2
```
# vault secrets enable -path=secret kv-v2
```