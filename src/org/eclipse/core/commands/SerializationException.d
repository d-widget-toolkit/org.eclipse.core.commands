/*******************************************************************************
 * Copyright (c) 2004, 2006 IBM Corporation and others.
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
module org.eclipse.core.commands.SerializationException;

import org.eclipse.core.commands.common.CommandException;

import java.lang.all;

/**
 * Signals that an exception occured while serializing a
 * {@link ParameterizedCommand} to a string or deserializing a String to a
 * {@link ParameterizedCommand}.
 * <p>
 * This class is not intended to be extended by clients.
 * </p>
 *
 * @since 3.2
 */
public final class SerializationException : CommandException {

    /**
     * Generated serial version UID for this class.
     */
    private static final long serialVersionUID = 2691599674561684949L;

    /**
     * Creates a new instance of this class with the specified detail message.
     *
     * @param message
     *            the detail message; may be <code>null</code>.
     */
    public this(String message) {
        super(message);
    }

    /**
     * Creates a new instance of this class with the specified detail message
     * and cause.
     *
     * @param message
     *            the detail message; may be <code>null</code>.
     * @param cause
     *            the cause; may be <code>null</code>.
     */
    public this(String message, Exception cause) {
        super(message, cause);
    }
}
