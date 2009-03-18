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
module org.eclipse.core.commands.Category;

import org.eclipse.core.commands.common.NamedHandleObject;
import org.eclipse.core.internal.commands.util.Util;
import org.eclipse.core.commands.ICategoryListener;
import org.eclipse.core.commands.CategoryEvent;

import java.lang.all;
import java.util.Collection;
import java.util.ArrayList;
import java.util.Iterator;

/**
 * <p>
 * A logical group for a set of commands. A command belongs to exactly one
 * category. The category has no functional effect, but may be used in graphical
 * tools that want to group the set of commands somehow.
 * </p>
 *
 * @since 3.1
 */
public final class Category : NamedHandleObject {

    /**
     * A collection of objects listening to changes to this category. This
     * collection is <code>null</code> if there are no listeners.
     */
    private Collection categoryListeners;

    /**
     * Constructs a new instance of <code>Category</code> based on the given
     * identifier. When a category is first constructed, it is undefined.
     * Category should only be constructed by the <code>CommandManager</code>
     * to ensure that identifier remain unique.
     *
     * @param id
     *            The identifier for the category. This value must not be
     *            <code>null</code>, and must be unique amongst all
     *            categories.
     */
    this(String id) {
        super(id);
    }

    /**
     * Adds a listener to this category that will be notified when this
     * category's state changes.
     *
     * @param categoryListener
     *            The listener to be added; must not be <code>null</code>.
     */
    public final void addCategoryListener(
            ICategoryListener categoryListener) {
        if (categoryListener is null) {
            throw new NullPointerException();
        }
        if (categoryListeners is null) {
            categoryListeners = new ArrayList();
        }
        if (!categoryListeners.contains(cast(Object)categoryListener)) {
            categoryListeners.add(cast(Object)categoryListener);
        }
    }

    /**
     * <p>
     * Defines this category by giving it a name, and possibly a description as
     * well. The defined property automatically becomes <code>true</code>.
     * </p>
     * <p>
     * Notification is sent to all listeners that something has changed.
     * </p>
     *
     * @param name
     *            The name of this command; must not be <code>null</code>.
     * @param description
     *            The description for this command; may be <code>null</code>.
     */
    public final void define(String name, String description) {
        if (name is null) {
            throw new NullPointerException(
                    "The name of a command cannot be null"); //$NON-NLS-1$
        }

        bool definedChanged = !this.defined;
        this.defined = true;

        bool nameChanged = !Util.equals(this.name, name);
        this.name = name;

        bool descriptionChanged = !Util.equals(this.description,
                description);
        this.description = description;

        fireCategoryChanged(new CategoryEvent(this, definedChanged,
                descriptionChanged, nameChanged));
    }

    /**
     * Notifies the listeners for this category that it has changed in some way.
     *
     * @param categoryEvent
     *            The event to send to all of the listener; must not be
     *            <code>null</code>.
     */
    private final void fireCategoryChanged(CategoryEvent categoryEvent) {
        if (categoryEvent is null) {
            throw new NullPointerException();
        }
        if (categoryListeners !is null) {
            Iterator listenerItr = categoryListeners.iterator();
            while (listenerItr.hasNext()) {
                ICategoryListener listener = cast(ICategoryListener) listenerItr
                        .next();
                listener.categoryChanged(categoryEvent);
            }
        }
    }

    /**
     * Removes a listener from this category.
     *
     * @param categoryListener
     *            The listener to be removed; must not be <code>null</code>.
     *
     */
    public final void removeCategoryListener(
            ICategoryListener categoryListener) {
        if (categoryListener is null) {
            throw new NullPointerException();
        }

        if (categoryListeners !is null) {
            categoryListeners.remove(cast(Object)categoryListener);
        }
    }

    /*
     * (non-Javadoc)
     *
     * @see org.eclipse.core.commands.common.HandleObject#toString()
     */
    public override String toString() {
        if (string is null) {
            string = Format( "Category({},{},{},{})", id, name, description, defined );
        }
        return string;
    }

    /*
     * (non-Javadoc)
     *
     * @see org.eclipse.core.commands.common.HandleObject#undefine()
     */
    public override void undefine() {
        string = null;

        final bool definedChanged = defined;
        defined = false;

        final bool nameChanged = name !is null;
        name = null;

        final bool descriptionChanged = description !is null;
        description = null;

        fireCategoryChanged(new CategoryEvent(this, definedChanged,
                descriptionChanged, nameChanged));
    }

}
