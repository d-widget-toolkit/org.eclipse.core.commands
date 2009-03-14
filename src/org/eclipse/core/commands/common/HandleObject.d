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
module org.eclipse.core.commands.common.HandleObject;

import org.eclipse.core.internal.commands.util.Util;
import org.eclipse.core.commands.common.IIdentifiable;
import org.eclipse.core.commands.common.EventManager;
import java.lang.all;

/**
 * <p>
 * An object that can exist in one of two states: defined and undefined. This is
 * used by APIs that want to give a handle to an object, even though the object
 * does not fully exist yet. This way, users can attach listeners to objects
 * before they come into existence. It also protects the API from users that do
 * not release references when they should.
 * </p>
 * <p>
 * To enforce good coding practice, all handle objects must implement
 * <code>equals</code> and <code>toString</code>. Please use
 * <code>string</code> to cache the result for <code>toString</code> once
 * calculated.
 * </p>
 * <p>
 * All handle objects are referred to using a single identifier. This identifier
 * is a instance of <code>String</code>. It is important that this identifier
 * remain unique within whatever context that handle object is being used. For
 * example, there should only ever be one instance of <code>Command</code>
 * with a given identifier.
 * </p>
 *
 * @since 3.1
 */
public abstract class HandleObject : EventManager,
        IIdentifiable {

    /**
     * The constant integer hash code value meaning the hash code has not yet
     * been computed.
     */
    private static const int HASH_CODE_NOT_COMPUTED = -1;

    /**
     * A factor for computing the hash code for all schemes.
     */
    private static const int HASH_FACTOR = 89;

    /**
     * The seed for the hash code for all schemes.
     */
    private static const int HASH_INITIAL;

    static this(){
        HASH_INITIAL =
        //typeid(char[]).getHash(& HandleObject.classinfo.name );
        java.lang.all.toHash(HandleObject.classinfo.name);
    }
    /**
     * Whether this object is defined. A defined object is one that has been
     * fully initialized. By default, all objects start as undefined.
     */
    protected /+transient+/ bool defined = false;

    /**
     * The hash code for this object. This value is computed lazily, and marked
     * as invalid when one of the values on which it is based changes.
     */
    private /+transient+/ int hashCode = HASH_CODE_NOT_COMPUTED;

    /**
     * The identifier for this object. This identifier should be unique across
     * all objects of the same type and should never change. This value will
     * never be <code>null</code>.
     */
    protected /+final+/ String id;

    /**
     * The string representation of this object. This string is for debugging
     * purposes only, and is not meant to be displayed to the user. This value
     * is computed lazily, and is cleared if one of its dependent values
     * changes.
     */
    protected /+transient+/ String string = null;

    /**
     * Constructs a new instance of <code>HandleObject</code>.
     *
     * @param id
     *            The id of this handle; must not be <code>null</code>.
     */
    protected this(String id) {
        if (id is null) {
            throw new NullPointerException(
                    "Cannot create a handle with a null id"); //$NON-NLS-1$
        }

        this.id = id;
    }

    /**
     * Tests whether this object is equal to another object. A handle object is
     * only equal to another handle object with the same id and the same class.
     *
     * @param object
     *            The object with which to compare; may be <code>null</code>.
     * @return <code>true</code> if the objects are equal; <code>false</code>
     *         otherwise.
     */
    public override int opEquals(Object object) {
        // Check if they're the same.
        if (object is this) {
            return true;
        }

        // Check if they're the same type.
        if (!(cast(HandleObject)object)) {
            return false;
        }

        // Check each property in turn.
        final HandleObject handle= cast(HandleObject) object;
        return Util.equals(id, handle.id)
                && (this.classinfo is handle.classinfo);
    }

    public /+override+/ final String getId() {
        return id;
    }

    /**
     * Computes the hash code for this object based on the id.
     *
     * @return The hash code for this object.
     */
    public final override hash_t toHash() {
        if (hashCode is HASH_CODE_NOT_COMPUTED) {
            hashCode = HASH_INITIAL * HASH_FACTOR + Util.toHash(id);
            if (hashCode is HASH_CODE_NOT_COMPUTED) {
                hashCode++;
            }
        }
        return hashCode;
    }

    /**
     * Whether this instance is defined. A defined instance is one that has been
     * fully initialized. This allows objects to effectively disappear even
     * though other objects may still have references to them.
     *
     * @return <code>true</code> if this object is defined; <code>false</code>
     *         otherwise.
     */
    public final bool isDefined() {
        return defined;
    }

    /**
     * The string representation of this object -- for debugging purposes only.
     * This string should not be shown to an end user.
     *
     * @return The string representation; never <code>null</code>.
     */
    public override abstract String toString();

    /**
     * Makes this object becomes undefined. This method should make any defined
     * properties <code>null</code>. It should also send notification to any
     * listeners that these properties have changed.
     */
    public abstract void undefine();
}
