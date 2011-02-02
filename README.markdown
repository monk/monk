Monk
====

Monk is a glue framework for web development.

It means that instead of installing all the tools you need for your
projects, you can rely on a Git repository, and Monk takes care of the
rest. By default, it ships with a Sinatra application that includes
Cutest, Stories, Webrat, Ohm and some other niceties, along with a
structure and helpful documentation to get your hands wet in no time.

But Monk also respects your tastes, and you are invited to create your
own versions of the skeleton app and your own list of dependencies. You
can add many different templates (different git repositories) and Monk
will help you manage them all.

Installation
------------

Ensure that RVM is installed. If it isn't, use:

    $ bash < <( curl http://rvm.beginrescueend.com/releases/rvm-install-head )

Install the Monk gem in the global RVM gemset:

    $ rvm use @global
    $ gem install monk

For more information on RVM, see the [RVM website](http://rvm.beginrescueend.com/).

Usage
-----

Once monk is installed, create your first project:

    $ monk init myapp

Try it out, and install the necessary gems:

    $ cd myapp
    $ monk install

Run the included test suite: (optional but recommended)

    $ rake

If the tests pass, it means that you can start hacking right away. If
they don't, just follow the instructions.

You may then start the web server:

    $ monk start

You can access your site at [http://localhost:4567](http://localhost:4567).
