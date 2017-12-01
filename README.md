<!-- vim: set filetype=markdown: -->
# skopos-auth-ad

This repository includes a Dockerfile, and supporting files, which may be used to build a modified Skopos image which includes support for authenticating users against an Active Directory server using PAM.

## Building a Modified Skopos Image

To build the modified Skopos image with AD login support:

- Clone this repository onto a host which has the Docker CLI installed.
- Optionally, edit the Dockerfile and change the base Skopos image name as desired.  Note that the base image must be based on Ubuntu (e.g. `opsani/skopos:edge`). Skopos images based on Alpine Linux use a different package manager (apk) and require different commands to install the needed PAM modules.
- Create the new container image by executing this command in the root directory of the cloned repository (change the new image tag as desired):  `build --tag my_registry/skopos:ads .`

## Starting Skopos with AD Support

The newly-created image can be used to start a Skopos engine, just like the original Skopos image.  For example:

```
docker run -d -p 8100:8100 --restart=unless-stopped --name skopos \
   -v /var/run/docker.sock:/var/run/docker.sock \
   my_registry/skopos:ads --autocert my-skopos-hostname.example --use-login
```

Additional options that may need to be added to the docker command line:

- If the environment in which Docker is running does not have your AD system as the DNS resolver, add one or more `--dns` options, specifying alternate DNS servers that are part of the AD domain and can answer the queries required to find an AD domain controller.
- If you already have a server certificate, map the file into the container's filesystem namespace with `-v /path/to/my/cert.pem:/cert.pem` and replace the `--autocert ...` option given to Skopos with `--certfile /cert.pem`. If starting Skopos as a docker-swarm service, the certificate can be mapped with the `--secret` option (unlike `-v`, this option allows starting the container on any swarm node).

When using the newly-built image to start Skopos, the freshly-started engine is functional and accessible on the network, but will not be able to authenticate immediately against AD. First, the container needs to be joined to the AD domain as a member. To accomplish this, run the following command, replacing the uppercase placeholder strings as described below:

```
docker exec -ti skopos /skopos/ad-join [-u ADMINUSR] [-g 'DOM\GROUP'] DOM REALM
```

- `ADMINUSR` is the name of a user (in the AD domain) that has permission to join servers to it. If the `-u` option is not given, the default is `Administrator`.
- `DOM\GROUP` specifies an optional group to which users must belong to be able to log in. If not given, *any* user with a valid domain login will be able to access Skopos. The group can be specified either in the form DOM\\GROUP or as an SID string (S-1-N-N-...). Because the name includes a backslash, it must be enclosed in quotes to prevent the shell from interpreting it as a meta-character.
- `DOM` is the short name of the AD domain. It is usually the rightmost part of the fully-qualified realm name (e.g. `EXAMPLE`, if the realm is `EXAMPLE.COM`); however, it may be different if the AD was set up by upgrading a Windows NT Domain Controller or is otherwise running in the NT-compatible 'mixed' mode. The short DOM name is what one normally sees on their Windows workstation login prompt, where the username is shown as DOM\User.
- `REALM` is the DNS name of the Active Directory realm.  It must be a fully-qualified DNS name.

The `ad-join` command must be run interactively (with the `docker exec -ti` option) and will prompt for the password of the domain admin user, to be able to join the domain. The password will not be remembered and the container retains no privileged access to the domain. It will keep only the name and random password generated for the 'machine account' created as part of the join operation. This 'machine account' has only one access right to the AD: to read the users and groups database.

The `ad-join` command may output some warning messages -- these are normal. If you see an output line that says "Joined 'XXX' to dns domain 'example.com'", the operation was successful.

Skopos is now ready to authenticate domain users. In the Skopos login page, enter the user name exactly as you see it on a Windows workstation login prompt, including the DOM\\ prefix, e.g.: `EXAMPLE\the-user`.

> NOTE:  user names without a DOM\\ prefix are treated as local user names and are authenticated against the /etc/passwd and /etc/shadow databases. Local users can be added just as for an unmodified Skopos container, with `docker exec skopos useradd new-user-name`.

## Removal and Upgrade

Unless special care is taken, Docker containers have a unique and non-reproducible hostname, which makes it impossible to 're-use' a domain-join setup if the container needs to be destroyed and re-made, as would normally be done to upgrade to a new version of Skopos. Therefore, the `ad-join` command would have to be re-run every time a new instance of the container is created. To prevent stale unused computer accounts from accumulating in the AD database, one could remove the container from the AD when it is intended to be shut down and removed. Just like the join itself, this can be done only by a domain administrator. Use the following command to remove a Skopos container from AD (replace 'Administrator' with the name of any user that is a domain admin or has permission to add/remove computers from the domain):

```
docker exec -ti skopos   net ads leave -U Administrator
```

When this is done, Skopos will no longer be able to authenticate domain users. The container can now be stopped and removed.
