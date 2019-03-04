FROM wodby/drupal:8-4.11.0
RUN mkdir /home/wodby/tmp
USER www-data
RUN mkdir /mnt/files/config/sync_dir
USER wodby
ADD --chown=wodby:wodby ./html /home/wodby/tmp
ADD --chown=root:root ./docker-entrypoint.sh /
RUN chmod 755 /home/wodby/tmp/web/sites/default
RUN rm /home/wodby/tmp/web/sites/default/settings.php
COPY --chown=wodby:wodby ./prod.settings.php /home/wodby/tmp/web/sites/default/settings.php
