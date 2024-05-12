namespace GitExtensions.Extensibility.Git;

public interface IGitCommandConfiguration
{
    void Add(GitConfigItem configItem, params string[] commands);
    IReadOnlyList<GitConfigItem> Get(string command);
}
