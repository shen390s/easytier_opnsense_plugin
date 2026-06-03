PLUGIN_NAME=		easytier
PLUGIN_VERSION=		1.0
PLUGIN_REVISION=	1
PLUGIN_COMMENT=		EasyTier P2P overlay network
PLUGIN_MAINTAINER=	your-email@example.com
PLUGIN_CATEGORIES=	net
PLUGIN_WWW=		https://easytier.rs

# EasyTier upstream version
EASYTIER_VERSION?=	2.6.4
EASYTIER_FREEBSD_VERSION?=	13.2
EASYTIER_ARCH?=		x86_64
EASYTIER_GITHUB=	https://github.com/EasyTier/EasyTier
EASYTIER_DISTFILE=	easytier-freebsd-${EASYTIER_FREEBSD_VERSION}-${EASYTIER_ARCH}-v${EASYTIER_VERSION}.zip
EASYTIER_DISTURL=	${EASYTIER_GITHUB}/releases/download/v${EASYTIER_VERSION}/${EASYTIER_DISTFILE}

DESTDIR?=
PREFIX?=		/usr/local

.include "../../Mk/plugins.mk"
