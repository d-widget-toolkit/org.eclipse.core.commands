/*******************************************************************************
 * Copyright (c) 2005 IBM Corporation and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *     IBM Corporation - initial API and implementation
 * Port to the D programming language:
 *     Frank Benoit <benoit@tionex.de>
 ******************************************************************************/

module org.eclipse.core.commands.common.AbstractHandleObjectEvent;

import org.eclipse.core.commands.common.AbstractBitSetEvent;

/**
 * <p>
 * An event fired from a <code>NamedHandleObject</code>. This provides
 * notification of changes to the defined state, the name and the description.
 * </p>
 *
 * @since 3.2
 */
public abstract class AbstractHandleObjectEvent : AbstractBitSetEvent {

    /**
     * The bit used to represent whether the category has changed its defined
     * state.
     */
    protected static const int CHANGED_DEFINED = 1;

    /**
     * The last used bit so that subclasses can add more properties.
     */
    protected static const int LAST_BIT_USED_ABSTRACT_HANDLE = CHANGED_DEFINED;

    /**
     * Constructs a new instance of <code>AbstractHandleObjectEvent</code>.
     *
     * @param definedChanged
     *            <code>true</code>, iff the defined property changed.
     */
    protected this( bool definedChanged) {
        if (definedChanged) {
            changedValues |= CHANGED_DEFINED;
        }
    }

    /**
     * Returns whether or not the defined property changed.
     *
     * @return <code>true</code>, iff the defined property changed.
     */
    public final bool isDefinedChanged() {
        return ((changedValues & CHANGED_DEFINED) !is 0);
    }
}
