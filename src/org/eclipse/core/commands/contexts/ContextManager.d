/*******************************************************************************
 * Copyright (c) 2000, 2007 IBM Corporation and others.
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

module org.eclipse.core.commands.contexts.ContextManager;

import org.eclipse.core.commands.contexts.IContextListener;
import org.eclipse.core.commands.contexts.IContextManagerListener;
import org.eclipse.core.commands.contexts.ContextEvent;
import org.eclipse.core.commands.contexts.ContextManagerEvent;
import org.eclipse.core.commands.contexts.Context;
import org.eclipse.core.commands.common.HandleObjectManager;
import org.eclipse.core.commands.util.Tracing;
import org.eclipse.core.internal.commands.util.Util;

import java.lang.all;
import java.util.Set;
import java.util.HashSet;
import java.util.Collections;

/**
 * <p>
 * A context manager tracks the sets of defined and enabled contexts within the
 * application. The manager sends notification events to listeners when these
 * sets change. It is also possible to retrieve any given context with its
 * identifier.
 * </p>
 * <p>
 * This class is not intended to be extended by clients.
 * </p>
 *
 * @since 3.1
 */
public final class ContextManager : HandleObjectManager,
        IContextListener {

    private static const String DEFER_EVENTS = "org.eclipse.ui.internal.contexts.deferEvents"; //$NON-NLS-1$
    private static const String SEND_EVENTS = "org.eclipse.ui.internal.contexts.sendEvents"; //$NON-NLS-1$

    /**
     * This flag can be set to <code>true</code> if the context manager should
     * print information to <code>System.out</code> when certain boundary
     * conditions occur.
     */
    public static bool DEBUG = false;

    /**
     * The set of active context identifiers. This value may be empty, but it is
     * never <code>null</code>.
     */
    private Set activeContextIds;
    private static Set EMPTY_SET;

    // allow the ContextManager to send one event for a larger delta
    private bool caching = false;

    private int cachingRef = 0;

    private bool activeContextsChange = false;

    private Set oldIds = null;

    public this(){
        activeContextIds = new HashSet();
        if( EMPTY_SET is null ){
            EMPTY_SET = new HashSet();
        }
    }

    /**
     * Activates a context in this context manager.
     *
     * @param contextId
     *            The identifier of the context to activate; must not be
     *            <code>null</code>.
     */
    public final void addActiveContext(String contextId) {
        if (DEFER_EVENTS.equals(contextId)) {
            cachingRef++;
            if (cachingRef is 1 ) {
                setEventCaching(true);
            }
            return;
        } else if (SEND_EVENTS.equals(contextId)) {
            cachingRef--;
            if (cachingRef is 0) {
                setEventCaching(false);
            }
            return;
        }

        if (activeContextIds.contains(contextId)) {
            return;
        }
        activeContextsChange = true;

        if (caching) {
            activeContextIds.add(contextId);
        } else {
            Set previouslyActiveContextIds = new HashSet(activeContextIds);
            activeContextIds.add(contextId);

            fireContextManagerChanged(new ContextManagerEvent(this, null,
                    false, true, previouslyActiveContextIds));
        }

        if (DEBUG) {
            Tracing.printTrace("CONTEXTS", activeContextIds.toString()); //$NON-NLS-1$
        }

    }

    /**
     * Adds a listener to this context manager. The listener will be notified
     * when the set of defined contexts changes. This can be used to track the
     * global appearance and disappearance of contexts.
     *
     * @param listener
     *            The listener to attach; must not be <code>null</code>.
     */
    public final void addContextManagerListener(
            IContextManagerListener listener) {
        addListenerObject(cast(Object)listener);
    }

    public final void contextChanged(ContextEvent contextEvent) {
        if (contextEvent.isDefinedChanged()) {
            Context context = contextEvent.getContext();
            String contextId = context.getId();
            bool contextIdAdded = context.isDefined();
            if (contextIdAdded) {
                definedHandleObjects.add(context);
            } else {
                definedHandleObjects.remove(context);
            }
            if (isListenerAttached()) {
                fireContextManagerChanged(new ContextManagerEvent(this,
                        contextId, contextIdAdded, false, null));
            }
        }
    }

    /**
     * Notifies all of the listeners to this manager that the set of defined
     * context identifiers has changed.
     *
     * @param event
     *            The event to send to all of the listeners; must not be
     *            <code>null</code>.
     */
    private final void fireContextManagerChanged(ContextManagerEvent event) {
        if (event is null) {
            throw new NullPointerException();
        }

        Object[] listeners = getListeners();
        for (int i = 0; i < listeners.length; i++) {
            IContextManagerListener listener = cast(IContextManagerListener) listeners[i];
            listener.contextManagerChanged(event);
        }
    }

    /**
     * Returns the set of active context identifiers.
     *
     * @return The set of active context identifiers; this value may be
     *         <code>null</code> if no active contexts have been set yet. If
     *         the set is not <code>null</code>, then it contains only
     *         instances of <code>String</code>.
     */
    public final Set getActiveContextIds() {
        return Collections.unmodifiableSet(activeContextIds);
    }

    /**
     * Gets the context with the given identifier. If no such context currently
     * exists, then the context will be created (but be undefined).
     *
     * @param contextId
     *            The identifier to find; must not be <code>null</code>.
     * @return The context with the given identifier; this value will never be
     *         <code>null</code>, but it might be undefined.
     * @see Context
     */
    public final Context getContext(String contextId) {
        checkId(contextId);

        Context context = cast(Context) handleObjectsById.get(contextId);
        if (context is null) {
            context = new Context(contextId);
            handleObjectsById.put(contextId, context);
            context.addContextListener(this);
        }

        return context;
    }

    /**
     * Returns the set of identifiers for those contexts that are defined.
     *
     * @return The set of defined context identifiers; this value may be empty,
     *         but it is never <code>null</code>.
     */
    public final Set getDefinedContextIds() {
        return getDefinedHandleObjectIds();
    }

    /**
     * Returns the those contexts that are defined.
     *
     * @return The defined contexts; this value may be empty, but it is never
     *         <code>null</code>.
     * @since 3.2
     */
    public final Context[] getDefinedContexts() {
        return arraycast!(Context)( definedHandleObjects
                .toArray(/+new Context[definedHandleObjects.size()]+/));
    }

    /**
     * Deactivates a context in this context manager.
     *
     * @param contextId
     *            The identifier of the context to deactivate; must not be
     *            <code>null</code>.
     */
    public final void removeActiveContext(String contextId) {
        if (!activeContextIds.contains(contextId)) {
            return;
        }

        activeContextsChange = true;
        if (caching) {
            activeContextIds.remove(contextId);
        } else {
            Set previouslyActiveContextIds = new HashSet(activeContextIds);
            activeContextIds.remove(contextId);

            fireContextManagerChanged(new ContextManagerEvent(this, null,
                    false, true, previouslyActiveContextIds));
        }

        if (DEBUG) {
            Tracing.printTrace("CONTEXTS", activeContextIds.toString()); //$NON-NLS-1$
        }
    }
    /**
     * Removes a listener from this context manager.
     *
     * @param listener
     *            The listener to be removed; must not be <code>null</code>.
     */
    public final void removeContextManagerListener(
            IContextManagerListener listener) {
        removeListenerObject(cast(Object)listener);
    }

    /**
     * Changes the set of active contexts for this context manager. The whole
     * set is required so that internal consistency can be maintained and so
     * that excessive recomputations do nothing occur.
     *
     * @param activeContextIds
     *            The new set of active context identifiers; may be
     *            <code>null</code>.
     */
    public final void setActiveContextIds(Set activeContextIds) {
        if (Util.equals(cast(Object)this.activeContextIds, cast(Object)activeContextIds)) {
            return;
        }

        activeContextsChange = true;

        Set previouslyActiveContextIds = this.activeContextIds;
        if (activeContextIds !is null) {
            this.activeContextIds = new HashSet();
            this.activeContextIds.addAll(activeContextIds);
        } else {
            this.activeContextIds = null;
        }

        if (DEBUG) {
            Tracing.printTrace("CONTEXTS", (activeContextIds is null) ? "none" //$NON-NLS-1$ //$NON-NLS-2$
                    : activeContextIds.toString());
        }

        if (!caching) {
            fireContextManagerChanged(new ContextManagerEvent(this, null,
                    false, true, previouslyActiveContextIds));
        }
    }

    /**
     * Set the manager to cache context id changes.
     *
     * @param cache
     *            <code>true</code> to turn caching on, <code>false</code>
     *            to turn caching off and send an event if necessary.
     * @since 3.3
     */
    private void setEventCaching(bool cache) {
        if (caching is cache) {
            return;
        }
        caching = cache;
        bool fireChange = activeContextsChange;
        Set holdOldIds = (oldIds is null?Collections.EMPTY_SET:oldIds);

        if (caching) {
            oldIds = new HashSet(activeContextIds);
        } else {
            oldIds = null;
        }
        activeContextsChange = false;

        if (!caching && fireChange) {
            fireContextManagerChanged(new ContextManagerEvent(this, null,
                    false, true, holdOldIds));
        }
    }
}
