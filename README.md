This will help you to setup MiDM Host on Ubuntu 20.04 server.
If you have Ubuntu 20.04 desktop or server, you can build the MiDM host easily.
### Prerequisites
1. Ubuntu 20.04 Server or desktop
2. Available internet connection to setup the latest apps. It won't be needed after the configuration.
4. 20GB storage(Recommended 60GB or more)
5. 2GB memory(Recommended 8G or more)
6. 2 cores CPU(Recommended 4 cores or more)

## Getting Started
1. Download this
2. Move to the downloaded folder.
3. Start setup script
```
$ sudo ./setup.sh
```
It will ask you whether you will install NginX & MongoDB, and about the MongoDB connection setttings.
Once it is defined, it'll automatically install the application which needs and initialize as default.

## Setup with arguments
If you would like to configure the parameters from the argument, you can do that.
```
$ sudo ./setup.sh -nginx <yes|no> -mongodb <yes|no> -files <path to store MiDM files> -webapp <path of webapp(war) file> -db.host <host ip or domain> -db.port <port> -db.name <db_name> -db.user <db user name> -db.password <password for the db user>
```
If there's argument not described, it will ask to enter the values.
