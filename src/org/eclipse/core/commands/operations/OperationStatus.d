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
 *******************************************************************************/
module org.eclipse.core.commands.operations.OperationStatus;

import org.eclipse.core.runtime.Status;

import java.lang.all;

/**
 * <p>
 * OperationStatus describes the status of a request to execute, undo, or redo
 * an operation.  This class may be instantiated by clients.
 * </p>
 *
 * @since 3.1
 */
public final class OperationStatus : Status {
    /**
     * NOTHING_TO_REDO indicates there was no operation available for redo.
     *
     * (value is 1).
     */
    public static const int NOTHING_TO_REDO = 1;

    /**
     * NOTHING_TO_UNDO indicates there was no operation available for undo.
     *
     * (value is 2).
     */
    public static const int NOTHING_TO_UNDO = 2;

    /**
     * OPERATION_INVALID indicates that the operation available for undo or redo
     * is not in a state to successfully perform the undo or redo.
     *
     * (value is 3).
     */
    public static const int OPERATION_INVALID = 3;

    /**
     * DEFAULT_PLUGIN_ID identifies the default plugin reporting the status.
     *
     * (value is "org.eclipse.core.commands").
     */
    static String DEFAULT_PLUGIN_ID = "org.eclipse.core.commands"; //$NON-NLS-1$

    /**
     * Creates a new operation status, specifying all properties.
     *
     * @param severity
     *            the severity for the status
     * @param pluginId
     *            the unique identifier of the relevant plug-in
     * @param code
     *            the informational code for the status
     * @param message
     *            a human-readable message, localized to the current locale
     * @param exception
     *            a low-level exception, or <code>null</code> if not
     *            applicable
     */
    public this(int severity, String pluginId, int code, String message, Exception exception) {
        super(severity, pluginId, code, message, exception);
    }
}
