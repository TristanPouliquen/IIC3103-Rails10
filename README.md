# Los Cuates del Tequila

## Pre-requisites

1. You must have Ruby installed (v>2.0.0)
2. You must have installed the bundler gem (else `gem install bundler`)
3. You must have MySQL installed and running

## Installation

1. Clone the project on your computer
2. Open a console in the folder of the project
3. Run `bundle install`
4. Run `rake db:create`
5. Run `rake db:migrate`

## Run the website locally

If everything went well for the installation, you only have to run `rails server`in your console.

## Deployment

1. Open a console in the folder of the project
2. Run `cap production deploy`
3. Check that everything is working on [the website](http://integra10.ing.puc.cl)
4. If anything went wrong, run `cap production deploy:rollback`to return to the previous version
