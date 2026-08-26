# 🪶 wp-lite Guide

`wp-lite` is the low-cost demo environment.

It creates one EC2 instance and installs both WordPress and MariaDB on that same instance. It does not create RDS, NAT Gateway, Load Balancer, or CloudFront.

## Best Use Cases

- Portfolio demos.
- Short-lived screenshots.
- Practicing Terraform workflows.
- Testing WordPress bootstrap scripts.

## You can add your own domain in the backend so that it has a proper site domain

!!! todo: demonstrate how to add ACM to create a https domain from person's choosing

## Deploy a wp-lite env

![long demo gif](../images/gifs//gif3_wp_lite_setup.gif)
🟢NOTE: The CLI has default parameters set in `[default-value]` which automatically apply by just pressing `Enter`.

### 1. Starting the script
From the project root, type the following:
```bash
chmod 700 scripts/start-demo.sh # that's if you never gave permissions
./scripts/start-demo.sh
```
The script checks your shell env to ensure that the necessary packages are installed for the script to use. It shows this by displaying green `[ok]` for every required package used.

### 2. Entering inputs for the script
For ease, a lot of the script is geared towards building a `wp-lite` deployment, so the default values have been preloaded as a suggestion by just pressing `Enter`.

Below is a simplified line-by-line input request to configure the script into building a `wp-lite` project as needed, with comments to explain the goal of what is trying to be improved:

```bash

Environment: wp-lite, wp-rds, or wp-mig [wp-lite]: # which deployment you want (wp-lite, wp-rds, wp-mig)

Website display name [Cloud WordPress Demo]: # the name of the website, can be anything

Use a custom static demo folder instead of website/default-site? yes or no [no]: # this is in case you wanted to push your own website source code, 'no' is default

AWS CLI profile name [default]: # the aws account moniker associated to your account that is saved in your aws-cli local install, usually the only one account is called 'default'

AWS region [us-east-1]: # which region you want to build all the supporting resources for this project, i.e. EC2, Database etc

Existing EC2 key pair name [replace-with-your-key-pair]: # type in an existing EC2 key-pair from your account

SSH allowed CIDR [0.0.0.0/0]: # if you know what IP schematic (public or private) you want to allow to your box, type it in. if not leave as is and then configure security settings later once up and running

EC2 instance type [t3.micro]: # default, simple EC2. Depending on goals, this may change to improve quality

```

Once set, the script will start Terraform, scaffolding resouces to then push onto AWS to build. Before doing so, the script will ask if these resources are okay. Type `yes` to conintue:
![create](../images/wp-lite/create_resources.png)

Then the script will run a while, building AWS resources through the local aws sso account set up before. There will be a heartbeat check on whether the EC2 instance is ready to be visited online:
![outputs](../images/wp-lite/outputs.png)

And then all the login information, to both the MariaDB and the Wordpress Admin page, with proper endpoint URLs are displayed for you to click through:
![outputs_final](../images/wp-lite/outputs-final.png)

With the links and login information provided, you can get to the homepage, and also the Wordpress dashboard to start editing your website:

Homepage
![homepage](../images/wp-lite/homepage.png)

Login Page
![login](../images/wp-lite/login.png)

Wordpress Dashboard
![dash](../images/wp-lite/dashboard.png)

When prompted for the database password, remember that this is the hidden MariaDB login WordPress uses internally. When prompted for the WordPress admin password, use a separate password for the `/wp-admin/` browser login.

After the site is live, the WordPress admin password can be changed from the WordPress dashboard.

After the instance finishes bootstrapping:

- Visit `/` for the WordPress site.
- Visit `/wp-admin/` for WordPress admin.
- Visit `/demo/` for the static Terraform/AWS demo pages.

Manual deployment:

```bash
cd terraform/environments/wp-lite
terraform init
terraform plan
terraform apply
```

Use placeholder values in committed files. Provide real database and WordPress admin passwords only through local variables, environment variables, or an ignored `.tfvars` file.

## Seed Demo Content

After WordPress is installed, copy the seed script to the instance and run it:

```bash
scp scripts/seed-wordpress.sh ubuntu@your-instance-public-dns:/tmp/seed-wordpress.sh
ssh ubuntu@your-instance-public-dns "chmod +x /tmp/seed-wordpress.sh && sudo SITE_URL='http://your-instance-public-dns' /tmp/seed-wordpress.sh"
```

## Destroy

Destroy this environment when the demo is finished.

```bash
terraform destroy
```
