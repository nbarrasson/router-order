<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="xml" indent="yes"/>
    
    <xsl:template match="/">
        <order>
            <!-- Order ID and Date -->
            <orderId>
                <xsl:value-of select="order/orderId"/>
            </orderId>
            <orderDate>
                <xsl:value-of select="order/orderDate"/>
            </orderDate>
            
            <!-- Contact Information -->
            <contact>
                <xsl:value-of select="concat(order/customer/contactPerson/firstName, ' ', order/customer/contactPerson/lastName)"/>
            </contact>
            <email>
                <xsl:value-of select="order/customer/contactPerson/email"/>
            </email>
            
            <!-- Billing Address -->
            <billingAddress>
                <street>
                    <xsl:value-of select="order/customer/billingAddress/street"/>
                </street>
                <city>
                    <xsl:value-of select="order/customer/billingAddress/city"/>
                </city>
                <postalCode>
                    <xsl:value-of select="order/customer/billingAddress/postalCode"/>
                </postalCode>
                <country>
                    <xsl:value-of select="order/customer/billingAddress/country"/>
                </country>
            </billingAddress>
            
            <!-- Product Details -->
            <product>
                <model>
                    <xsl:value-of select="order/product/model"/>
                </model>
                <version>
                    <xsl:value-of select="order/product/version"/>
                </version>
                <quantity>
                    <xsl:value-of select="order/product/quantity"/>
                </quantity>
            </product>
            
            <!-- Delivery Information -->
            <delivery>
                <method>
                    <xsl:value-of select="order/delivery/method"/>
                </method>
                <trackingNumber>
                    <xsl:value-of select="order/delivery/trackingNumber"/>
                </trackingNumber>
                <estimatedDeliveryDate>
                    <xsl:value-of select="order/delivery/estimatedDeliveryDate"/>
                </estimatedDeliveryDate>
                <deliveryAddress>
                    <street>
                        <xsl:value-of select="order/delivery/deliveryAddress/street"/>
                    </street>
                    <city>
                        <xsl:value-of select="order/delivery/deliveryAddress/city"/>
                    </city>
                    <postalCode>
                        <xsl:value-of select="order/delivery/deliveryAddress/postalCode"/>
                    </postalCode>
                    <country>
                        <xsl:value-of select="order/delivery/deliveryAddress/country"/>
                    </country>
                </deliveryAddress>
                <deliveryInstructions>
                    <xsl:value-of select="order/delivery/deliveryInstructions"/>
                </deliveryInstructions>
            </delivery>
        </order>
    </xsl:template>
</xsl:stylesheet>
