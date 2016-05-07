# Los Cuates del Tequila

##Documentation

The project documentation is availabler [here](Documentacion Entrega 1.pdf). It contains the system's description, diagrams of the different processes implemented.

The API documentation is available [here](http://integra10.ing.puc.cl/api/documentacion).

## Pre-requisites

1. You must have Ruby installed (v>2.0.0)
2. You must have installed the bundler gem (else `gem install bundler`)
3. You must have MySQL installed and running

## Installation

1. Clone the project on your computer
2. Open a console in the folder of the project
3. Run `bundle install` (if it doesn't try updating bundler by running `gem update bundler` )
4. Copy the `config/database.yml.dist` and `config/secrets.yml.dist` removing the `.dist` extension
5. Verify the credentials in `config/database.yml` so that they match those of your MySQL installation
6. Ask a member of the group for the `application.yml` file to get the needed environment variables settings
7. Run `rake db:create`
8. Run `rake db:migrate`

## Run the website locally

If everything went well for the installation, you only have to run `rails server`in your console.

## Deployment

Deployment is done in two steps. A verification step on [the development platform](http://dev.integra10.ing.puc.cl)
before actually deploying to [the production platform](http://integra10.ing.puc.cl) when the new code has been tested.

To deploy follow these steps:

1. Open a console in the folder of the project
2. Run `bundle exec cap <environment> deploy` where environment can be `development` or `production` following to which
platform you want to deploy
3. Check that everything is working on the platform you've deployed to.
4. If anything went wrong, run `cap <environment> deploy:rollback`to return to the previous version
