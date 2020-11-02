﻿using GitExtensions.Core.Commands.Events;

namespace GitExtensions.Extensibility.Events
{
    /// <summary>
    /// Interface to implement if you wish to receive OnPostBrowseInitialize.
    /// </summary>
    public interface IPostBrowseInitializeHandler
    {
        void OnPostBrowseInitialize(GitUIEventArgs e);
    }
}
