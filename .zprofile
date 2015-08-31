### Set _JAVA_OPTIONS picked up by Java and used by play
export _JAVA_OPTIONS="-Xms2496m -Xmx2496m"

export SBT_OPTS="-Dsbt.jse.engineType=Node -Xms2496m -Xmx2496m -XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled -XX:ReservedCodeCacheSize=128m -XX:+UseCodeCacheFlushing"

bash /usr/bin/tdm
