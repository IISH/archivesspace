## Plugin development in Archivesspace

The documentation below (the ==== line) is not entirely correct. The latest documentation on development is on:
https://archivesspace.github.io/tech-docs/development/dev.html

That page assumes you develop directly on the host. This is an choice. Here we use docker containers running on an Ubuntu 24.04.

### Alias

    alias dcomp='docker compose -f docker-compose-dev-full.yml'

or fixed

    echo "alias dcomp='docker compose -f docker-compose-dev-full.yml'" > $HOME/.bash_aliases

#### Look at the configuration

It is set for hot-reloading with one hello_world plugin enabled:

    config/config.rb

### 1. Build an initial development archivesspace image first

You need to build this only once. Tag it meaningfully

    docker build -f Dev.dockerfile --tag archivesspace-plugin-development .

### 2. Start the applications and look around

    dcomp up -d
    dcomp ps

- db contains your mysql database
- solr the index
- archivesspace-app sleeps. It contains the software to run archivesspace components

### 3. bootstrap the archivesspace folder

You need this only once after the first git clone:

    dcomp exec app ./build/run bootstrap

### 4. Look in the database

The archivesspace database is setup with the arguments in the file **.env.docker.dev**

    dcomp exec db mysql -u as -pas123 archivesspace -e 'show databases'
    
It ought to show you a database: archivesspace
    +--------------------+
    | Database           |
    +--------------------+
    | archivesspace      |
    | information_schema |
    | performance_schema |
    +--------------------+

But no tables.

### 5. Add schema to the database

There is nothing in there, so add a schema.

    dcomp exec app ./build/run db:migrate
    dcomp exec db mysql -u as -pas123 archivesspace -e 'show tables'

    +-------------------------------------+
    | Tables_in_archivesspace             |
    +-------------------------------------+
    | accession                           |
    | accession_component_links_rlshp     |
    | active_edit                         |
    | agent_alternate_set                 |
    | agent_contact                       |
    | agent_conventions_declaration       |
    | agent_corporate_entity              |
    | agent_family                        |
    | agent_function                      |
    | agent_gender                        |
    | agent_identifier                    |
    | agent_maintenance_history           |
    | agent_occupation                    |
    | agent_other_agency_codes            |
    | agent_person                        |
    | agent_place                         |
    | agent_record_control                |
    | agent_record_identifier             |
    | agent_resource                      |
    | agent_software                      |
    | agent_sources                       |
    | agent_topic                         |
    | archival_object                     |
    | ark_name                            |
    | ark_uniq_check                      |
    | assessment                          |
    | assessment_attribute                |
    | assessment_attribute_definition     |
    | assessment_attribute_note           |
    | assessment_reviewer_rlshp           |
    | assessment_rlshp                    |
    | auth_db                             |
    | classification                      |
    | classification_creator_rlshp        |
    | classification_rlshp                |
    | classification_term                 |
    | classification_term_creator_rlshp   |
    | collection_management               |
    | container_profile                   |
    | custom_report_template              |
    | date                                |
    | deaccession                         |
    | default_values                      |
    | deleted_records                     |
    | digital_object                      |
    | digital_object_component            |
    | enumeration                         |
    | enumeration_value                   |
    | event                               |
    | event_link_rlshp                    |
    | extent                              |
    | external_document                   |
    | external_id                         |
    | file_version                        |
    | group                               |
    | group_permission                    |
    | group_user                          |
    | hello_world_schema_info             |
    | instance                            |
    | instance_do_link_rlshp              |
    | job                                 |
    | job_created_record                  |
    | job_input_file                      |
    | job_modified_record                 |
    | lang_material                       |
    | language_and_script                 |
    | linked_agent_term                   |
    | linked_agents_rlshp                 |
    | location                            |
    | location_function                   |
    | location_profile                    |
    | location_profile_rlshp              |
    | metadata_rights_declaration         |
    | name_authority_id                   |
    | name_corporate_entity               |
    | name_family                         |
    | name_person                         |
    | name_software                       |
    | note                                |
    | note_persistent_id                  |
    | notification                        |
    | oai_config                          |
    | owner_repo_rlshp                    |
    | parallel_name_corporate_entity      |
    | parallel_name_family                |
    | parallel_name_person                |
    | parallel_name_software              |
    | permission                          |
    | preference                          |
    | rde_template                        |
    | related_accession_rlshp             |
    | related_agents_rlshp                |
    | repository                          |
    | required_fields                     |
    | resource                            |
    | revision_statement                  |
    | rights_restriction                  |
    | rights_restriction_type             |
    | rights_statement                    |
    | rights_statement_act                |
    | rights_statement_pre_088            |
    | schema_info                         |
    | sequence                            |
    | session                             |
    | spawned_rlshp                       |
    | structured_date_label               |
    | structured_date_range               |
    | structured_date_single              |
    | sub_container                       |
    | subject                             |
    | subject_agent_subrecord_place_rlshp |
    | subject_agent_subrecord_rlshp       |
    | subject_rlshp                       |
    | subject_term                        |
    | subnote_metadata                    |
    | surveyed_by_rlshp                   |
    | system_event                        |
    | telephone                           |
    | term                                |
    | top_container                       |
    | top_container_housed_at_rlshp       |
    | top_container_link_rlshp            |
    | top_container_profile_rlshp         |
    | used_language                       |
    | user                                |
    | user_defined                        |
    | vocabulary                          |
    | whosaidhello                        |
    +-------------------------------------+

Note the very last table in the list: whosaidhello
That one did not come from the migrations archivesspace core,
it came from the plugin:

    plugins/hello_world/migrations/001_hello_world_schema.rb

### 6. Add demo data to the database

Although you could already spin up the archivesspace services right now and login with 'admin' 'admin' there is some demo data already:

    dcomp cp build/mysql_db_fixtures/demo.sql.gz db:/tmp/
    dcomp exec db gzip -d /tmp/demo.sql.gz
    dcomp exec db mysql -u as -pas123 archivesspace -e 'source /tmp/demo.sql'

### 7. Run the archivesspace components

Terminal A:

Using pry and remote-pry:

    dcomp exec app ./build/run backend:devserver

Terminal B:

Using pry and remote-pry:

    dcomp exec app ./build/run frontend:devserver

Optional Terminal C for the public catalog:

It is optional, as the plugin does not extend anything here.

    dcomp exec app ./build/run public:devserver

Optional Terminal D:

Also optional for the OAI2 server.

    dcomp exec app ./build/run oai:devserver

### 8. Look around

The backend also known as the Archivesspace API:

http://localhost:4567

The staff client:

http://localhost:3000

The public had you start it:

http://localhost:3001

The oai service had you start it:

http://localhost:4568

### 9. Debugging

The development image we built will do hotswapping, so the code is immediately rendered.

Remote debugging is possible with **pry**:

Docs: https://github.com/pry/pry

Place **pry** in ruby code after the code you find interesting:

    binding.pry

Similar in the views:

    <% binding.pry %>


### This is the base scaffold.

==============================================================

# Git flow
- This project uses rebases instead of merges. It is important to make sure you are following the correct git flow to keep the branches consistent.
- [Playbook article here](http://playbook-staging.notch8.com/en/git/rebasing) describing how to rebase for this project

# Full Dev Env in Docker

- Pull down the code: `https://github.com/notch8/archivesspace`
- If its the first time you are working on this project, `cd` into the project and run `cp docker-compose-dev-full.yml docker-compose.yml`
- To run the project: `docker compose up app`
- You will need to migrate the database to see the app run: `docker-compose exec app ./build/run db:migrate`
- Open ports 3001 for `public`, 3000 for `frontend` and 4567 for `backend`
- To sign into the staff interface username and password are both: admin


See https://archivesspace.github.io/tech-docs/development/dev.html for additional info

# Troubleshooting

## Steps to bash into your container & bundle

1. Make sure the services section of `docker-compose.yml` looks like this (the "command" needs to be uncommented):
```
services:
  app:
    build:
      context: .
      dockerfile: Dev.dockerfile
    command: bash -l -c "tail -f /dev/null"
    depends_on:
      - db
      - solr
      - db-test
      - solr-test
    env_file:
      - .env.docker.dev
    volumes:
      - .:/archivesspace
      - build:/archivesspace/build
      - ./build/build.xml:/archivesspace/build/build.xml
    ports:
      - 3000:3000
      - 3001:3001
      - 4567:4567
```

2. start the containers: `docker-compose up app`
3. bash into the container: `docker-compose exec app bash`
4. if you need to bundle the frontend (staff interface): `./build/run bundle:frontend`
5. if you need to bundle the public interface: `./build/run bundle:public`
5. if you need to update an individual gem in the public interface: `./build/run bundle:public:update -Donly-gem=GEM-NAME-HERE`

## To start the containers separately:
1. new tab- bash into the container: `docker-compose exec app bash`
2. run the individual command to start the back end: `./build/run backend:devserver`
3. new tab- bash into the container again: `docker-compose exec app bash`
4. run the individual command to start the front end only: `./build/run frontend:devserver`

## How to use demo data
1. Copy the demo db into the db docker container: `docker cp build/mysql_db_fixtures/demo.sql.gz archivesspace_db_1:/` or `docker cp build/mysql_db_fixtures/demo.sql.gz archivesspace-db-1:/` depending on the name of your docker container
  - run `docker ps` to see the name of your db container
2. bash into the container for db: `docker-compose exec db sh`
3. Unzip sql file: `gzip demo.sql.gz``
4. import the database: `mysql -p archivesspace < demo.sql`, password is 123456

# Running the test suite
1. Bash into the container: `docker compose exec app bash`
2. Unset frontend proxy URL: `unset APPCONFIG_FRONTEND_PROXY_URL`
  - you will need to run this each time you open a new terminal/shell, and are running frontend and Selenium specs

## The following commands will run the full set of tests for each aSpace app:
- Frontend: `./build/run frontend:test` or `./build/run frontend:selenium`
- Public: `./build/run public:test`
- Indexer: `./build/run indexer:test`
- Backend: `./build/run backend:test`

## Other useful commands for testing
- Run a single test file (you will replace the path at the end of the file or the command as needed).
  - Examples:
    - `./build/run frontend:test -Dpattern=features/repositories_spec.rb`

