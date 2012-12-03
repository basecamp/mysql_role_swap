#mysql\_role\_swap


mysql_role_swap is a script written in Ruby to perform all of the tasks that we normally perform when promoting a slave database to master. It performs all of the necessary checks to be sure that the transition is as smooth as possible. It uses the mysql and activerecord libraries to perform these tasks.

## Design Concepts:
mysql_role_swap is based on a few key design concepts: The script should be easy to understand and trouble shoot. The script should handle errors gracefully and provide ample data for manual recovery in the event human intervention is needed. We should be deterministic about the state of each step of the failover process.

## History:
In April 2011, after planning yet another manual database failover, Taylor shared the use of a statemachine and original design concept with John. One weekend later version one was born and reliably working on some test virtual machines. Since April 2011 John has shepherded the script through multiple rounds of testing in a staging environment. Taylor got the bright idea to add support for moving a virtual IP to the script, and since then the script has been used numerous times in production database environments without issue.

## Improvements:
We've designed mysql_role_swap to do work reliably in our environment at [37signals](http://37signals.com) however we believe through wider adoption and contributions from other organizations this script can become even more efficient and reliable. Almost all of the configuration is done by our Chef recipes -- and thus things are a little environment specific right now. With your help we can make this a little less 37-specific.

# Getting started
### Installation
#### Pre-requisites

How do I use it?

The script has been deployed on all of our database servers. And it is located at:

    /usr/local/bin/mysql_role_swap

When running the script you must specify at least one of the following options:

* Database Instance Name (-d): The name of the MySQL instance that you are swapping roles on. (This is used create the path to the cluster.yml file)
* Full Config Path (-c): Full path to the cluster.yml file.

Optional options:
* Check (-s): The check option will only run the preflight checks on the database and will not attempt to fail over.
* Force (-f): The force option will not prompt you before failing over the database. If there is a configuration problem the failover will not proceed. (use carefully)


You also need a cluster.yml file so the script can do all it's magic correctly.

Here's a sample cluster.yml:

    floating_ip: 10.10.10.37
    floating_ip_cidr: /32
    master_ipmi_address: 10.10.99.137

    database_one:
      adapter: mysql
      username: failover_user
      password: iluvsql
      primary_database: 37_production
      host: 10.10.9.137
      port: 3306
      slave_password: iluvsql2

    database_two:
      adapter: mysql
      username: failover_user
      password: iluvsql
      primary_database: 37_production
      host: 10.10.9.138
      port: 3306
      slave_password: iluvsql2

Example Usage:

Using the "-d" option:

    mysql_role_swap -d failovertest
    Current Cluster Configuration:

    Floating IP: 10.10.3.160

    Master: dbslave:3310
    MySQL Replication Role: master
    Floating IP Role: master
    MySQL Version: [5.1.45-log]
    Read-Only: false
    Arping Path: /usr/bin/arping

    Slave: shr-db-02:3307
    MySQL Replication Role: slave
    Floating IP Role: slave
    MySQL Version: [5.1.45-log]
    Read-Only: true
    Arping Path: /usr/bin/arping


# Getting help and contributing

### Getting help with mysql_role_swap
The fastest way to get help is to send an email to mysqlroleswap@librelist.com. 
Github issues and pull requests are checked regularly.

### Contributing
Pull requests with passing tests are welcomed and appreciated.

# License

     Copyright (c) 2012 37signals (37signals.com)

     Permission is hereby granted, free of charge, to any person obtaining
     a copy of this software and associated documentation files (the
     "Software"), to deal in the Software without restriction, including
     without limitation the rights to use, copy, modify, merge, publish,
     distribute, sublicense, and/or sell copies of the Software, and to
     permit persons to whom the Software is furnished to do so, subject to
     the following conditions:

     The above copyright notice and this permission notice shall be
     included in all copies or substantial portions of the Software.

     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
     EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
     NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
     LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
     OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
     WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
