FROM wodby/drupal:8-4.12.4
RUN ls -A | xargs rm -rf
RUN mkdir /mnt/files/config/sync_dir
RUN chmod 775 /mnt/files/config/sync_dir
ADD --chown=wodby:wodby ./html /tmp
ADD --chown=root:root ./docker-entrypoint.sh /
RUN chmod 755 /tmp/web/sites/default
RUN rm /tmp/web/sites/default/settings.php
COPY --chown=wodby:wodby ./prod.settings.php /tmp/web/sites/default/settings.php
