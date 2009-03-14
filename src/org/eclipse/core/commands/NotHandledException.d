/*******************************************************************************
 * Copyright (c) 2004, 2005 IBM Corporation and others.
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
module org.eclipse.core.commands.NotHandledException;

import org.eclipse.core.commands.common.CommandException;

import java.lang.all;

/**
 * Signals that an attempt was made to access the properties of an unhandled
 * object.
 * <p>
 * This class is not intended to be extended by clients.
 * </p>
 *
 * @since 3.1
 */
public final class NotHandledException : CommandException {

    /**
     * Generated serial version UID for this class.
     *
     * @since 3.1
     */
    private static final long serialVersionUID = 3256446914827726904L;

    /**
     * Creates a new instance of this class with the specified detail message.
     *
     * @param s
     *            the detail message.
     */
    public this(String s) {
        super(s);
    }
}
