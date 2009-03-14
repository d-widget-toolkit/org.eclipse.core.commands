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
module org.eclipse.core.commands.ExecutionException;

import org.eclipse.core.commands.common.CommandException;
import java.lang.all;

/**
 * Signals that an exception occured during the execution of a command.
 * <p>
 * This class is not intended to be extended by clients.
 * </p>
 *
 * @since 3.1
 */
public final class ExecutionException : CommandException {

    /**
     * Generated serial version UID for this class.
     *
     * @since 3.1
     */
    private static final long serialVersionUID = 3258130262767448120L;

    /**
     * Creates a new instance of this class with the specified detail message.
     *
     * @param message
     *            the detail message; may be <code>null</code>.
     * @since 3.2
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
