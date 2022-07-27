# System for Fuse mounts of S3 Storage

```sh
(base) jovyan@jupyter-7577f4977c-flvw4:~$ ./bin/mc ls s3proxy
[2022-04-10 19:17:00 UTC]     0B premium/
[2022-04-10 19:15:45 UTC]     0B standard/
(base) jovyan@jupyter-7577f4977c-flvw4:~$ ./bin/mc ls s3proxy/standard/
(base) jovyan@jupyter-7577f4977c-flvw4:~$ echo Hey > swag.txt
(base) jovyan@jupyter-7577f4977c-flvw4:~$ ./bin/mc cp swag.txt s3proxy/standard/
...vyan/swag.txt:  4 B / 4 B ┃▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓┃ 2 B/s 1s
(base) jovyan@jupyter-7577f4977c-flvw4:~$ ls buckets/
premium/  standard/ 
(base) jovyan@jupyter-7577f4977c-flvw4:~$ ls buckets/standard/swag.txt 
buckets/standard/swag.txt
(base) jovyan@jupyter-7577f4977c-flvw4:~$ cat buckets/standard/swag.txt 
Hey
(base) jovyan@jupyter-7577f4977c-flvw4:~$ echo Heyyoo > swag.txt
(base) jovyan@jupyter-7577f4977c-flvw4:~$ ./bin/mc cp swag.txt s3proxy/standard/
...vyan/swag.txt:  7 B / 7 B ┃▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓┃ 19 B/s 0s
(base) jovyan@jupyter-7577f4977c-flvw4:~$ cat buckets/standard/swag.txt 
Heyyoo
(base) jovyan@jupyter-7577f4977c-flvw4:~$ 
```

# S3 Proxy UI Debugging

**Steps to reprouce** (just mocking the s3proxy part w/ filesystem back-end):

1. `make kind-create && kubectl create ns aaw-fc` (create kind cluster)
2. `kustomize build manifests/s3proxy/fancy | tee manifest.yaml | kubectl apply -f -`

**Temporary instructions for local kind cluster debugging** (remove this documentation once solution is found)
2. comment out the networkpolicy and virtualservice from the `kustomization.yaml` in `manifests/s3proxy/fancy` - kind cluster doesn't have istio crd installed and network policies are unecessary for local debugging
3. make minio bucket by opening a shell into `minio-cli` pod and running  `mc alias set s3proxy http://s3proxy:80` then `mc mb s3proxy/standard`.
4. for local example, make the s3proxy filesystem pod use `/tmp` as its storage directory b/c the container process has write permissions in `/tmp`.



**Dynamically listing buckets**
Not possible according to https://github.com/aws/aws-sdk-js/blob/307e82673b48577fce4389e4ce03f95064e8fe0d/doc-src/templates/api-versions/model_documentor.rb#L264-L265 and https://stackoverflow.com/a/29950510 - need to 

# Note: kind instead of k3d

This is because we need dpkg installed for the blob-csi-driver, and `k3d` is too minimal for that.

# Two S3Proxy instances

```
s3proxy
|- standard
|- premium
`- fdi-unclassified

s3proxy-prob
|- standard-ro
|- premium-ro
|- prob
`- fdi-prob
```

# Architecture

The architecture has a nice split:

- Create or Find Storage Containers, Create PVs (readwrite or readonly), and create PVCs in the user namespace

- Automatically discover PVCs and bind them to Notebooks, Workflows, or S3Proxy pods. (Goofys Webhook)

**Refreshes/Updates**

- Users will need to restart their notebooks to trigger refresh of mounts (in the situation where an FDI bucket gets added, for example).

- Recommend that S3Proxy comes with a CronJob that rolls out a restart on an interval. (Similar to the AAD Pod refresher.)

**TODO: What happens if the storage account credentials get rotated?**

## BlobCSI controller :heavy_check_mark:

The BlobCSI Profile Controller loops through profiles and AAW Storage accounts:

- Creates a container (bucket) in each storage account if it doesn't exist.
- Creates a PersistentVolume binding to it using the Azure Blob CSI Driver. The driver authenticates using a secret within the `azure-blob-csi-system`
- Creates a PersistentVolumeClaim binding to the PersistentVolume in the profile's namespace.[^A Gatekeeper policy is in place to ensure that no other PVCs are allowed to bind to this PV]

### FDI Submodule :x:

Use OPA sdk to check if a user has access to a given bucket, and determine what permissions they have. (We can only implement RW/RO)

## Gatekeeper Policies :heavy_exclamation_mark:

~~The PersistentVolumes are created with a `profile` label, matching the users profile. A Gatekeeper policy ensure that `pvc.metadata.namespace == pv.metadata.labels.profile`. So that users cannot bind other users volumes.~~ **This is resolved using a `claimRef` on the PV**.

**Also, the classification of the PV and PVCs must match.** (Still need to check this.)
Alternatively, prevent users from creating these PVCs themselves. 

## ~~Goofys~~ Blob CSI Injector :heavy_check_mark:

The Goofys injector is repurposed:

- Instead of using a fixed list of mounts, it uses the `blob.aaw.statcan.gc.ca/automount` label to select volumes to mount.
- It further differentiates between `unclassified` and `protected-b` PVCs, only mounting to the correct pods.
