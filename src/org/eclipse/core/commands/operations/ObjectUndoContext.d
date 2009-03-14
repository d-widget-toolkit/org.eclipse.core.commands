/*******************************************************************************
 * Copyright (c) 2005, 2006 IBM Corporation and others.
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
module org.eclipse.core.commands.operations.ObjectUndoContext;

import org.eclipse.core.commands.operations.UndoContext;
import org.eclipse.core.commands.operations.IUndoContext;

import java.lang.all;
import java.util.List;
import java.util.ArrayList;

/**
 * <p>
 * An undo context that can be used to represent any given object. Clients
 * can add matching contexts to this context.  This class may be instantiated
 * by clients.
 * </p>
 *
 * @since 3.1
 */
public final class ObjectUndoContext : UndoContext {

    private Object object;

    private String label;

    private List children;

    /**
     * Construct an operation context that represents the given object.
     *
     * @param object
     *            the object to be represented.
     */
    public this(Object object) {
        this(object, null);
    }

    /**
     * Construct an operation context that represents the given object and has a
     * specialized label.
     *
     * @param object
     *            the object to be represented.
     * @param label
     *            the label for the context
     */
    public this(Object object, String label) {
        this.object = object;
        this.label = label;
        children = new ArrayList();
    }

    /*
     * (non-Javadoc)
     *
     * @see org.eclipse.core.commands.operations.IUndoContext#getLabel()
     */
    public override String getLabel() {
        if (label !is null) {
            return label;
        }
        if (object !is null) {
            return object.toString();
        }
        return super.getLabel();
    }

    /**
     * Return the object that is represented by this context.
     *
     * @return the object represented by this context.
     */
    public Object getObject() {
        return object;
    }

    /**
     * Add the specified context as a match of this context. Contexts added as
     * matches of this context will be interpreted as a match of this context
     * when the history is filtered for a particular context. Adding a match
     * allows components to create their own contexts for implementing
     * specialized behavior, yet have their operations appear in a more
     * global context.
     *
     * @param context
     *            the context to be added as a match of this context
     */
    public void addMatch(IUndoContext context) {
        children.add(cast(Object)context);
    }

    /**
     * Remove the specified context as a match of this context. The context will
     * no longer be interpreted as a match of this context when the history is
     * filtered for a particular context. This method has no effect if the
     * specified context was never previously added as a match.
     *
     * @param context
     *            the context to be removed from the list of matches for this
     *            context
     */
    public void removeMatch(IUndoContext context) {
        children.remove(cast(Object)context);
    }

    /*
     * (non-Javadoc)
     *
     * @see org.eclipse.core.commands.operations.IUndoContext#matches(IUndoContext
     *      context)
     */
    public override bool matches(IUndoContext context) {
        // Check first for explicit matches that have been assigned.
        if (children.contains(cast(Object)context)) {
            return true;
        }
        // Contexts for equal objects are considered matching
        if ( null !is cast(ObjectUndoContext)context  && getObject() !is null) {
            return getObject().opEquals((cast(ObjectUndoContext)context).getObject()) !is 0;
        }
        // Use the normal matching implementation
        return super.matches(context);
    }

    /**
     * The string representation of this operation.  Used for debugging purposes only.
     * This string should not be shown to an end user.
     *
     * @return The string representation.
     */
    public override String toString() {
        return getLabel();
    }


}
