{% from 'redmine/map.jinja' import redmine with context %}

include:
  - redmine.install
{% if redmine.use_unicorn %}
  - redmine.unicorn
  - redmine.service
{% endif %}
