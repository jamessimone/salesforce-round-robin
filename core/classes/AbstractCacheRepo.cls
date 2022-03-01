public abstract class AbstractCacheRepo implements Cache.CacheBuilder {
  public Object doLoad(String requiredBySalesforce) {
    return this.populateCache();
  }

  public void updateCache(Object cachedItem) {
    this.getPartition().put(this.getCacheKey(), cachedItem);
  }

  protected abstract String getCachePartitionName();
  protected abstract String getCacheKey();
  protected abstract Object populateCache();

  protected Object getFromCache() {
    return this.getPartition().get(this.getCacheBuilder(), this.getCacheKey());
  }

  protected virtual Type getCacheBuilder() {
    // the well-known hack for extracting the name
    // of the current class at runtime
    String className = String.valueOf(this).split(':')[0];
    return Type.forName(className);
  }

  private Cache.OrgPartition getPartition() {
    Cache.OrgPartition partition;
    try {
      Cache.OrgPartition.validatePartitionName(this.getCachePartitionName());
      partition = Cache.Org.getPartition(this.getCachePartitionName());
    } catch (cache.Org.OrgCacheException orgCacheEx) {
      partition = new Cache.OrgPartition(this.getCachePartitionName());
    }
    return partition;
  }
}
