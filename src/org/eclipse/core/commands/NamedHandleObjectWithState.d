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

module org.eclipse.core.commands.NamedHandleObjectWithState;

import org.eclipse.core.commands.common.NamedHandleObject;
import org.eclipse.core.commands.common.NotDefinedException;
import org.eclipse.core.commands.IObjectWithState;
import org.eclipse.core.commands.State;
import org.eclipse.core.commands.INamedHandleStateIds;

import java.lang.all;
import java.util.Map;
import java.util.HashMap;
import java.util.Set;

/**
 * <p>
 * A named handle object that can carry state with it. This state can be used to
 * override the name or description.
 * </p>
 * <p>
 * Clients may neither instantiate nor extend this class.
 * </p>
 *
 * @since 3.2
 */
abstract class NamedHandleObjectWithState : NamedHandleObject,
        IObjectWithState {

    /**
     * An empty string array, which can be returned from {@link #getStateIds()}
     * if there is no state.
     */
    private static const String[] NO_STATE = null;

    /**
     * The map of states currently held by this command. If this command has no
     * state, then this will be <code>null</code>.
     */
    private Map states = null;

    /**
     * Constructs a new instance of <code>NamedHandleObject<WithState/code>.
     *
     * @param id
     *            The identifier for this handle; must not be <code>null</code>.
     */
    protected this(String id) {
        super(id);
    }

    public void addState(String stateId, State state) {
        if (state is null) {
            throw new NullPointerException("Cannot add a null state"); //$NON-NLS-1$
        }

        if (states is null) {
            states = new HashMap(3);
        }
        states.put(stateId, state);
    }

    public override final String getDescription() {
        String description = super.getDescription(); // Trigger a NDE.

        State descriptionState = getState(INamedHandleStateIds.DESCRIPTION);
        if (descriptionState !is null) {
            Object value = descriptionState.getValue();
            if (value !is null) {
                return value.toString();
            }
        }

        return description;
    }

    public override final String getName() {
        String name = super.getName(); // Trigger a NDE, if necessary.

        State nameState = getState(INamedHandleStateIds.NAME);
        if (nameState !is null) {
            final Object value = nameState.getValue();
            if (value !is null) {
                return value.toString();
            }
        }

        return name;
    }

    public final State getState(String stateId) {
        if ((states is null) || (states.isEmpty())) {
            return null;
        }

        return cast(State) states.get(stateId);
    }

    public final String[] getStateIds() {
        if ((states is null) || (states.isEmpty())) {
            return NO_STATE;
        }

        Set stateIds = states.keySet();
        return stringcast( stateIds.toArray());
    }

    public void removeState(String id) {
        if (id is null) {
            throw new NullPointerException("Cannot remove a null id"); //$NON-NLS-1$
        }

        if (states !is null) {
            states.remove(id);
            if (states.isEmpty()) {
                states = null;
            }
        }
    }

}
