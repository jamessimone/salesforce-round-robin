public abstract class AbstractCacheRepo implements Cache.CacheBuilder {
  public Object doLoad(String requiredBySalesforce) {
    return this.populateCache();
  }

  public void updateCache(Object cachedItem) {
    this.getPartition()?.put(this.getCacheKey(), cachedItem);
  }

  protected abstract String getCachePartitionName();
  protected abstract String getCacheKey();
  protected abstract Object populateCache();

  protected Object getFromCache() {
    Object cachedItem = this.getPartition()?.get(this.getCacheBuilder(), this.getCacheKey());
    if (cachedItem == null) {
      // the item is only null when there's an issue with the packaging org not properly
      // creating the cache partition; in this case, we "know" what the value will be
      // and can manually load it
      cachedItem = this.populateCache();
    }
    return cachedItem;
  }

  protected virtual Type getCacheBuilder() {
    // the well-known hack for extracting the name
    // of the current class at runtime
    String className = String.valueOf(this).split(':')[0];
    return Type.forName(className);
  }

@SuppressWarnings('PMD.EmptyCatchBlock')
private Cache.OrgPartition getPartition() {
    Cache.OrgPartition partition;
    try {
      partition = Cache.Org.getPartition(this.getCachePartitionName());
    } catch (cache.Org.OrgCacheException orgCacheEx) {
      // do nothing - there seem to be some timing dependencies on when
      // it's possible to use Platform Cache while packaging.
    }
    return partition;
  }
}
