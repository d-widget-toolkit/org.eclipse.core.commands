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
module org.eclipse.core.commands.ParameterTypeEvent;

import org.eclipse.core.commands.common.AbstractHandleObjectEvent;
import org.eclipse.core.commands.ParameterType;

import java.lang.all;

/**
 * An instance of this class describes changes to an instance of
 * {@link ParameterType}.
 * <p>
 * This class is not intended to be extended by clients.
 * </p>
 *
 * @see IParameterTypeListener#parameterTypeChanged(ParameterTypeEvent)
 * @since 3.2
 */
public final class ParameterTypeEvent : AbstractHandleObjectEvent {

    /**
     * The parameter type that has changed. This value is never
     * <code>null</code>.
     */
    private final ParameterType parameterType;

    /**
     * Constructs a new instance.
     *
     * @param parameterType
     *            The parameter type that changed; must not be <code>null</code>.
     * @param definedChanged
     *            <code>true</code>, iff the defined property changed.
     */
    this(ParameterType parameterType,
            bool definedChanged) {

        super(definedChanged);

        if (parameterType is null) {
            throw new NullPointerException();
        }

        this.parameterType = parameterType;
    }

    /**
     * Returns the instance of the parameter type that changed.
     *
     * @return the instance of the parameter type that changed. Guaranteed not
     *         to be <code>null</code>.
     */
    public final ParameterType getParameterType() {
        return parameterType;
    }

}
