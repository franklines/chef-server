# Chef Server Docker Container Image
![N|Solid](https://i.imgur.com/xPY9jpK.png)
chef-server will run Chef Server 12 in an Ubuntu Trusty 14.04 LTS container.
Image Size: Approximately 1GB

This is a fork of: [base/chef-server](https://registry.hub.docker.com/u/base/chef-server/).

# Environment
#### Protocol / Port
Chef is running over HTTPS/443 by default.
You can however change that to another port by adding `-e SSL_PORT=new_port` to the `docker run` command below and update the expose port `-p` accordingly.

# SSL certificate
When Chef Server gets configured it creates an SSL certificate based on the container's FQDN (i.e "103d6875c1c5" which is the "CONTAINER ID"). This default behavior has been changed to always produce an SSL certificate file named "chef-server.crt".
You can change the certificate name by adding  `-e CONTAINER_NAME=new_name` to the `docker run` command. Remember to reflect that change in config.rb!

# Logs
`/var/log/` is accessible via a volume directory. Feel free to optionally to use it with the `docker run` command above by adding: `-v ~/chef-logs:/var/log`

# DNS
The container needs to be **DNS resolvable!**
Be sure **'chef-server'** or **$CONTAINER_NAME** is pointing to the container's IP!
This needs to be done to match the SSL certificate name with the `chef_server_url ` from knife's `config.rb` file.

# Setup Chef User & Organization
The following parameters have been added to assist you in defining a default chef user and organization.
| Parameter        | Description            | 
| ------------- |:-------------:| 
| CHEF_USER      | Define your chef username. If not set, username defaults to admin. | 
| CHEF_PASS      | Define your chef user's password. Default generates a random password.      |  
| CHEF_MAIL | Sets your chef user's email address. Default is admin@<server hostname>.      |   
| CHEF_ORG | Defines the name of the organization that is created during setup. Default is set to 'my_org'.|
| CHEF_ORGDESC | Sets your chef organization's description. If not set, default is 'Default organization'. |

Set these parameters after the `-e` switch. Example below.
```bash
$ sudo docker run --privileged -t -e CONTAINER_NAME='<desired name>' CHEF_USER='<username>' CHEF_PASS='<password>' CHEF_MAIL='<user@example.com>' CHEF_ORG='<example_org>' CHEF_ORGDESC='<example org>'  --name chef-server -d -p 443:443 cbuisson/chef-server
```

## Start the container
Docker command:

```bash
$ docker run --privileged -t --name chef-server -d -p 443:443 cbuisson/chef-server
```

Follow the installation:

```bash
$ docker logs -f chef-server
```

## Setup knife

Once Chef Server 12 is configured, you can download the Knife admin keys with these steps:

#### Login to a shell session on your container.

```bash
sudo docker exec -it <CONTAINER ID> /bin/bash
```
#### Copy your user & organization pem keys.
```bash
cat /etc/chef/<username>.pem
cat /etc/chef/<organization>-validator.pem
```
Save the above keys to your local workstation (where you have knife installed). Then create a config.rb file with the contents.
```bash
vim ~/.chef/config.rb
```

*config.rb* example:

```ruby
log_level                :info
log_location             STDOUT
cache_type               'BasicFile'
node_name                'admin'
client_key               '/home/<user>/.chef/<username>.pem'
validation_client_name   'my_org-validator'
validation_key           '/home/<user>/.chef/<organization>-validator.pem'
chef_server_url          'https://<chef-server>:$SSL_PORT/organizations/<organization>'
```

When the config.rb file is ready, you will need to get the SSL certificate file from the container to access Chef Server:

```bash
cbuisson@server:~/.chef# knife ssl fetch
WARNING: Certificates from chef-server will be fetched and placed in your trusted_cert
directory (/home/<user>/.chef/trusted_certs).

Knife has no means to verify these are the correct certificates. You should
verify the authenticity of these certificates after downloading.

Adding certificate for chef-server in /home/<user>/.chef/trusted_certs/chef-server.crt
```

You should now be able to use the knife command!
```bash
<user>@server:~# knife user list
admin
```
**Done!**

##### Note
Chef-Server running inside a container isn't officially supported by [Chef](https://www.chef.io/about/) and as a result the webui isn't available.
However the webui is not required since you can interact with Chef-Server via the `knife` and `chef-server-ctl` commands.

##### Tags
v1.0: Chef Server 11
v2.x: Chef Server 12
