# Explicit permissions for sealing
path "sys/seal" {
    capabilities = ["update", "sudo"]
}

# Explicit permissions for unsealing
path "sys/unseal" {
    capabilities = ["update", "sudo"]
}

# Permission to view seal status 
path "sys/seal-status" {
    capabilities = ["read", "sudo"]
}
