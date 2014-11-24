from __future__ import with_statement
#from fabric.api import local, settings, abort, run, cd
from fabric.api import *
from fabric.contrib.console import confirm
from fabric.operations import sudo

env.hosts = ['vtfx.dev.mainstorconcept.de']

def prepare_deploy():
    local("./manage.py test rating")
    local("echo aca puede correr un test funcional")

def merge():
    local("git checkout master")
    local("git merge develop")
    local("git checkout develop")
    local("git push")

def deploy():
    base_dir = '/var/www/vtfx/'
    repo_dir = '/repo'
    virtualenv =  '/var/www/vtfx/env'

    with cd(repo_dir):
        sudo("git pull")

    with cd(base_dir):
        sudo("touch maintenance")
        with prefix('source ' + virtualenv + '/bin/activate'):
            #sudo("pip install -r " + virtualenv + "/requirements.txt")
            with cd('./repo/webapp'):
                sudo("echo 'yes' | ./manage.py collectstatic")
                run("./manage.py syncdb --noinput")
                run("./manage.py migrate")
            sudo("service nginx reload")
            sudo("service uwsgi restart")

        # recargar cache de pagespeed
        sudo("rm maintenance")
