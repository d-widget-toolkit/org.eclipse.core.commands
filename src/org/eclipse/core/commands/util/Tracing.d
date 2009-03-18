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

module org.eclipse.core.commands.util.Tracing;

import java.lang.all;

/**
 * <p>
 * A utility class for printing tracing output to the console.
 * </p>
 * <p>
 * Clients must not extend or instantiate this class.
 * </p>
 *
 * @since 3.2
 */
public final class Tracing {

    /**
     * The separator to place between the component and the message.
     */
    public static const String SEPARATOR = " >>> "; //$NON-NLS-1$

    /**
     * <p>
     * Prints a tracing message to standard out. The message is prefixed by a
     * component identifier and some separator. See the example below.
     * </p>
     *
     * <pre>
     *        BINDINGS &gt;&gt; There are 4 deletion markers
     * </pre>
     *
     * @param component
     *            The component for which this tracing applies; may be
     *            <code>null</code>
     * @param message
     *            The message to print to standard out; may be <code>null</code>.
     */
    public static final void printTrace(String component,
            String message) {
        StringBuffer buffer = new StringBuffer();
        if (component.length !is 0) {
            buffer.append(component);
        }
        if ((component.length !is 0) && (message.length !is 0)) {
            buffer.append(SEPARATOR);
        }
        if (message.length !is 0) {
            buffer.append(message);
        }
        getDwtLogger().trace( __FILE__, __LINE__, "{}", buffer.toString());
    }

    /**
     * This class is not intended to be instantiated.
     */
    private this() {
        // Do nothing.
    }
}
