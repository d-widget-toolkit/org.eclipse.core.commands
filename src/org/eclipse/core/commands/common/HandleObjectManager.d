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

module org.eclipse.core.commands.common.HandleObjectManager;

import org.eclipse.core.commands.common.HandleObject;
import org.eclipse.core.commands.common.EventManager;
import java.lang.all;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.Set;

/**
 * <p>
 * A manager of {@link HandleObject} instances. This has some common behaviour
 * which is shared between all such managers.
 * </p>
 * <p>
 * Clients may extend.
 * </p>
 *
 * @since 3.2
 */
public abstract class HandleObjectManager : EventManager {

    /**
     * The set of handle objects that are defined. This value may be empty, but
     * it is never <code>null</code>.
     */
    protected const Set definedHandleObjects;

    /**
     * The map of identifiers (<code>String</code>) to handle objects (
     * <code>HandleObject</code>). This collection may be empty, but it is
     * never <code>null</code>.
     */
    protected const Map handleObjectsById;

    public this(){
        definedHandleObjects = new HashSet();
        handleObjectsById = new HashMap();
    }

    /**
     * Verifies that the identifier is valid. Exceptions will be thrown if the
     * identifier is invalid in some way.
     *
     * @param id
     *            The identifier to validate; may be anything.
     */
    protected final void checkId(String id) {
        if (id is null) {
            throw new NullPointerException(
                    "A handle object may not have a null identifier"); //$NON-NLS-1$
        }

        if (id.length < 1) {
            throw new IllegalArgumentException(
                    "The handle object must not have a zero-length identifier"); //$NON-NLS-1$
        }
    }

    /**
     * Returns the set of identifiers for those handle objects that are defined.
     *
     * @return The set of defined handle object identifiers; this value may be
     *         empty, but it is never <code>null</code>.
     */
    protected final HashSet getDefinedHandleObjectIds() {
        HashSet definedHandleObjectIds = new HashSet(definedHandleObjects
                .size());
        Iterator handleObjectItr = definedHandleObjects.iterator();
        while (handleObjectItr.hasNext()) {
            HandleObject handleObject = cast(HandleObject) handleObjectItr
                    .next();
            String id = handleObject.getId();
            definedHandleObjectIds.add(id);
        }
        return definedHandleObjectIds;
    }
}
