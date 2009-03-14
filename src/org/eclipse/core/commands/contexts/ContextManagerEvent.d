/*******************************************************************************
 * Copyright (c) 2003, 2005 IBM Corporation and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *     IBM Corporation - initial API and implementation
 * Port to the D programming language:
 *     Frank Benoit <benoit@tionex.de>
 *******************************************************************************/
module org.eclipse.core.commands.contexts.ContextManagerEvent;

import org.eclipse.core.commands.contexts.ContextManager;
import org.eclipse.core.commands.common.AbstractBitSetEvent;

import java.lang.all;
import java.util.Set;

/**
 * <p>
 * An event indicating that the set of defined context identifiers has changed.
 * </p>
 *
 * @since 3.1
 * @see IContextManagerListener#contextManagerChanged(ContextManagerEvent)
 */
public final class ContextManagerEvent : AbstractBitSetEvent {

    /**
     * The bit used to represent whether the set of defined contexts has
     * changed.
     */
    private static const int CHANGED_CONTEXT_DEFINED = 1 << 1;

    /**
     * The bit used to represent whether the set of active contexts has changed.
     */
    private static const int CHANGED_CONTEXTS_ACTIVE = 1;

    /**
     * The context identifier that was added or removed from the list of defined
     * context identifiers.
     */
    private const String contextId;

    /**
     * The context manager that has changed.
     */
    private const ContextManager contextManager;

    /**
     * The set of context identifiers (strings) that were active before the
     * change occurred. If the active contexts did not changed, then this value
     * is <code>null</code>.
     */
    private const Set previouslyActiveContextIds;

    /**
     * Creates a new instance of this class.
     *
     * @param contextManager
     *            the instance of the interface that changed; must not be
     *            <code>null</code>.
     * @param contextId
     *            The context identifier that was added or removed; may be
     *            <code>null</code> if the active contexts are changing.
     * @param contextIdAdded
     *            Whether the context identifier became defined (otherwise, it
     *            became undefined).
     * @param activeContextsChanged
     *            Whether the list of active contexts has changed.
     * @param previouslyActiveContextIds
     *            the set of identifiers of previously active contexts. This set
     *            may be empty. If this set is not empty, it must only contain
     *            instances of <code>String</code>. This set must be
     *            <code>null</code> if activeContextChanged is
     *            <code>false</code> and must not be null if
     *            activeContextChanged is <code>true</code>.
     */
    public this(ContextManager contextManager,
            String contextId, bool contextIdAdded,
            bool activeContextsChanged,
            Set previouslyActiveContextIds) {
        if (contextManager is null) {
            throw new NullPointerException();
        }

        this.contextManager = contextManager;
        this.contextId = contextId;
        this.previouslyActiveContextIds = previouslyActiveContextIds;

        if (contextIdAdded) {
            changedValues |= CHANGED_CONTEXT_DEFINED;
        }
        if (activeContextsChanged) {
            changedValues |= CHANGED_CONTEXTS_ACTIVE;
        }
    }

    /**
     * Returns the context identifier that was added or removed.
     *
     * @return The context identifier that was added or removed. This value may
     *         be <code>null</code> if no context identifier was added or
     *         removed.
     */
    public final String getContextId() {
        return contextId;
    }

    /**
     * Returns the instance of the interface that changed.
     *
     * @return the instance of the interface that changed. Guaranteed not to be
     *         <code>null</code>.
     */
    public final ContextManager getContextManager() {
        return contextManager;
    }

    /**
     * Returns the set of identifiers to previously active contexts.
     *
     * @return the set of identifiers to previously active contexts. This set
     *         may be empty. If this set is not empty, it is guaranteed to only
     *         contain instances of <code>String</code>. This set is
     *         guaranteed to be <code>null</code> if
     *         haveActiveContextChanged() is <code>false</code> and is
     *         guaranteed to not be <code>null</code> if
     *         haveActiveContextsChanged() is <code>true</code>.
     */
    public final Set getPreviouslyActiveContextIds() {
        return previouslyActiveContextIds;
    }

    /**
     * Returns whether the active context identifiers have changed.
     *
     * @return <code>true</code> if the collection of active contexts changed;
     *         <code>false</code> otherwise.
     */
    public final bool isActiveContextsChanged() {
        return ((changedValues & CHANGED_CONTEXTS_ACTIVE) !is 0);
    }

    /**
     * Returns whether the list of defined context identifiers has changed.
     *
     * @return <code>true</code> if the list of context identifiers has
     *         changed; <code>false</code> otherwise.
     */
    public final bool isContextChanged() {
        return (contextId !is null);
    }

    /**
     * Returns whether the context identifier became defined. Otherwise, the
     * context identifier became undefined.
     *
     * @return <code>true</code> if the context identifier became defined;
     *         <code>false</code> if the context identifier became undefined.
     */
    public final bool isContextDefined() {
        return (((changedValues & CHANGED_CONTEXT_DEFINED) !is 0) && (contextId !is null));
    }
}
