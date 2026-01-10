"use client"

import { useState, useEffect } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
    DialogTrigger,
} from "@/components/ui/dialog"
import {
    AlertDialog,
    AlertDialogAction,
    AlertDialogCancel,
    AlertDialogContent,
    AlertDialogDescription,
    AlertDialogFooter,
    AlertDialogHeader,
    AlertDialogTitle,
} from "@/components/ui/alert-dialog"
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow,
} from "@/components/ui/table"
import { Badge } from "@/components/ui/badge"
import { Switch } from "@/components/ui/switch"
import { Plus, Search, Pencil, Trash2, FileText, Copy, RefreshCw, Check, Users, Smartphone } from "lucide-react"
import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from "@/components/ui/select"

interface User {
    uuid: string;
    name: string;
    limit_gb: number;
    device_limit: number;
    device_count: number;
    used_bytes: number;
    expiry: number;
    status: string;
    group_name?: string;
    group_id?: number;
}

// Xray Reality Public Key (Placeholder - Replace with real key)
const REALITY_PBK = "7jKk75S-8_tN5p6qC_D9r1Y2z8u3o4p5q6r7s8t9u0v";
const SNI = "www.microsoft.com";

function generateLink(conf: any, type: string) {
    const uuid = conf.uuid;
    const ip = conf.server;
    const port = conf.port;
    const name = encodeURIComponent(`${conf._meta?.core_name || "Aether"}-${type.toUpperCase()}`);

    if (type === 'vless') {
        // VLESS Reality
        return `vless://${uuid}@${ip}:${port}?security=reality&encryption=none&pbk=${REALITY_PBK}&fp=chrome&type=tcp&sni=${SNI}&sid=12345678&flow=xtls-rprx-vision#${name}`;
    } else if (type === 'xhttp') {
        // VLESS XHTTP
        return `vless://${uuid}@${ip}:${port}?security=none&encryption=none&type=xhttp&path=/xhttp&mode=auto#${name}-XHTTP`;
    } else if (type === 'vmess') {
        // VMess WS
        const vmessJson = {
            v: "2", ps: decodeURIComponent(name), add: ip, port: port, id: uuid, aid: "0",
            scy: "auto", net: "ws", type: "none", host: "", path: "/ws", tls: ""
        };
        return "vmess://" + btoa(JSON.stringify(vmessJson));
    } else if (type === 'trojan') {
        // Trojan
        return `trojan://${uuid}@${ip}:${port}?security=none#${name}`;
    }
    return "";
}

export default function UsersPage() {
    const [searchTerm, setSearchTerm] = useState("")
    const [users, setUsers] = useState<User[]>([])
    const [addDialogOpen, setAddDialogOpen] = useState(false)
    const [editDialogOpen, setEditDialogOpen] = useState(false)
    const [deleteDialogOpen, setDeleteDialogOpen] = useState(false)
    const [configDialogOpen, setConfigDialogOpen] = useState(false)
    const [renewDialogOpen, setRenewDialogOpen] = useState(false)
    const [selectedUser, setSelectedUser] = useState<User | null>(null)
    const [formData, setFormData] = useState({ name: "", limit_gb: "", device_limit: 3 })
    const [configData, setConfigData] = useState("")
    const [copied, setCopied] = useState(false)
    const [groups, setGroups] = useState([])
    const [assignDialogOpen, setAssignDialogOpen] = useState(false)
    const [selectedGroup, setSelectedGroup] = useState("")
    const [activeTab, setActiveTab] = useState("general")

    // Device Management State
    const [manageDeviceOpen, setManageDeviceOpen] = useState(false)
    const [userDevices, setUserDevices] = useState<any[]>([])
    const [newDevice, setNewDevice] = useState({ hardware_id: "", label: "" })

    // Template State
    const [templates, setTemplates] = useState([])
    const [createTemplateDialogOpen, setCreateTemplateDialogOpen] = useState(false)
    const [bulkTemplateDialogOpen, setBulkTemplateDialogOpen] = useState(false)
    const [bulkResultDialogOpen, setBulkResultDialogOpen] = useState(false)
    const [createdLinks, setCreatedLinks] = useState<string[]>([])

    const [templateFormData, setTemplateFormData] = useState({
        template_id: 0,
        username: "",
        note: ""
    })

    const [bulkTemplateData, setBulkTemplateData] = useState({
        template_id: 0,
        count: 1,
        strategy: "random", // 'random' | 'sequence'
        username: "user", // base username for sequence
        note: ""
    })

    const fetchTemplates = () => {
        fetch('/api/configs') // Reusing configs endpoint as templates for now? No, wait. 
        // Logic says "/api/user/from_template" uses "user_template_id"? 
        // Ah, in previous context 'config_templates' replaced 'configs'. 
        // Let's assume /api/configs returns the templates we need.
        // Or if we implemented a specific /api/templates? 
        // Checking Main.go: No /api/templates. We have /api/configs. 
        // ConfigsPage manages "config_templates". 
        // So fetching /api/configs is correct.
        fetch('/api/configs')
            .then(res => res.json())
            .then(data => setTemplates(data || []))
            .catch(err => console.error("Failed to load templates", err))
    }

    const fetchUsers = () => {
        fetch('/api/users')
            .then(res => res.json())
            .then(data => {
                if (Array.isArray(data)) {
                    setUsers(data)
                } else {
                    console.error("API returned non-array:", data)
                    setUsers([])
                }
            })
            .catch(err => {
                console.error('Failed to load users:', err)
                setUsers([])
            })
    }

    const fetchGroups = () => {
        fetch('/api/groups')
            .then(res => res.json())
            .then(data => setGroups(data || []))
    }

    useEffect(() => {
        fetchUsers()
        fetchGroups()
        fetchTemplates()
    }, [])

    const handleAddUser = async () => {
        const uuid = crypto.randomUUID()
        await fetch('/api/users', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                uuid,
                name: formData.name,
                limit_gb: parseFloat(formData.limit_gb),
                device_limit: formData.device_limit
            })
        })
        setAddDialogOpen(false)
        setFormData({ name: "", limit_gb: "", device_limit: 3 })
        fetchUsers()
    }

    const handleEditUser = async () => {
        if (!selectedUser) return
        await fetch('/api/users', {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                uuid: selectedUser.uuid,
                name: formData.name,
                limit_gb: parseFloat(formData.limit_gb),
                device_limit: formData.device_limit || 3
            })
        })
        setEditDialogOpen(false)
        fetchUsers()
    }

    const openEditDialog = (user: User, tab: string = "general") => {
        setSelectedUser(user)
        setFormData({
            name: user.name,
            limit_gb: (user.limit_gb || 0).toString(),
            device_limit: user.device_limit || 3
        })
        setSelectedGroup(user.group_id ? user.group_id.toString() : "")
        setActiveTab(tab)
        fetchUserDevices(user.uuid)
        setEditDialogOpen(true)
    }

    const handleDeleteUser = async () => {
        await fetch(`/api/users?uuid=${selectedUser.uuid}`, { method: 'DELETE' })
        setDeleteDialogOpen(false)
        fetchUsers()
    }

    const [configLinks, setConfigLinks] = useState<string[]>([])
    const [subscriptionUrl, setSubscriptionUrl] = useState("")

    const openConfig = async (user: User) => {
        setSelectedUser(user)
        const subUrl = `${window.location.protocol}//${window.location.host}/sub?uuid=${user.uuid}`
        setSubscriptionUrl(subUrl)

        // 1. Fetch JSON for Dialog UI
        try {
            const res = await fetch(`/api/user/config?uuid=${user.uuid}`)
            if (res.ok) {
                const text = await res.text()
                setConfigData(text) // Store JSON string for parsing in render
            } else {
                setConfigData("")
            }
        } catch (e) {
            console.error("Failed to fetch config json", e)
            setConfigData("")
        }

        // 2. Fetch Subscription (Base64) for Link List (Optional, but good for validation)
        try {
            const res = await fetch(subUrl)
            if (res.ok) {
                const text = await res.text()
                try {
                    const decoded = atob(text)
                    const links = decoded.split('\n').filter(l => l.trim() !== "")
                    setConfigLinks(links)
                } catch (e) {
                    // If sub returns non-base64 (e.g. error message), ignore
                    setConfigLinks([])
                }
            } else {
                setConfigLinks([])
            }
        } catch (e) {
            console.error("Failed to fetch sub", e)
            setConfigLinks([])
        }

        setConfigDialogOpen(true)
        setCopied(false)
    }

    const handleCopyConfig = () => {
        navigator.clipboard.writeText(configData)
        setCopied(true)
        setTimeout(() => setCopied(false), 2000)
    }

    const handleRenewUUID = async () => {
        const res = await fetch('/api/user', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ old_uuid: selectedUser.uuid })
        })
        const data = await res.json()
        setRenewDialogOpen(false)
        alert(`New UUID: ${data.new_uuid}\n\nPlease update client configuration!`)
        fetchUsers()
    }

    const handleStatusToggle = async (user: any) => {
        const newStatus = user.status === 'active' ? 'inactive' : 'active'
        await fetch('/api/users', {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                uuid: user.uuid,
                name: user.name,
                limit_gb: user.limit,
                status: newStatus
            })
        })
        fetchUsers()
    }

    const [removeGroupDialogOpen, setRemoveGroupDialogOpen] = useState(false)

    // Consolidated Handlers (reused logic)
    const handleAssignGroup = async () => {
        if (!selectedUser) return
        const groupId = parseInt(selectedGroup)
        await fetch('/api/users/assign-group', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                user_uuid: selectedUser.uuid,
                group_id: groupId
            })
        })
        alert("Group assigned!")

        // Find group name for UI update
        const group = groups.find((g: any) => g.id === groupId) as any
        setSelectedUser({
            ...selectedUser,
            group_id: groupId,
            group_name: group ? group.name : "Unknown"
        })
        fetchUsers()
    }

    const confirmRemoveGroup = () => {
        setRemoveGroupDialogOpen(true)
    }

    const handleRemoveGroup = async () => {
        if (!selectedUser || !selectedUser.group_id) return

        const res = await fetch(`/api/users/assign-group?user_uuid=${selectedUser.uuid}&group_id=${selectedUser.group_id}`, {
            method: 'DELETE'
        })

        if (res.ok) {
            setSelectedGroup("")
            // Update selectedUser locally to reflect change immediately in UI
            setSelectedUser({ ...selectedUser, group_id: undefined, group_name: undefined })
            fetchUsers()
            setRemoveGroupDialogOpen(false)
        } else {
            alert("Failed to remove group")
        }
    }

    const handleCreateFromTemplate = async () => {
        if (!templateFormData.template_id || !templateFormData.username) return;

        const res = await fetch('/api/user/from_template', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                user_template_id: templateFormData.template_id,
                username: templateFormData.username,
                note: templateFormData.note
            })
        })

        if (res.ok) {
            setCreateTemplateDialogOpen(false)
            fetchUsers()
            setTemplateFormData({ template_id: 0, username: "", note: "" })
        } else {
            alert("Failed to create user (Username might exist)")
        }
    }

    const handleBulkFromTemplate = async () => {
        if (!bulkTemplateData.template_id || bulkTemplateData.count < 1) return;

        const res = await fetch('/api/users/bulk/from_template', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                user_template_id: bulkTemplateData.template_id,
                count: bulkTemplateData.count,
                strategy: bulkTemplateData.strategy,
                username: bulkTemplateData.username,
                note: bulkTemplateData.note
            })
        })

        if (res.ok) {
            const data = await res.json()
            setCreatedLinks(data.subscription_urls || [])
            setBulkTemplateDialogOpen(false)
            setBulkResultDialogOpen(true)
            fetchUsers()
        } else {
            alert("Failed to create bulk users")
        }
    }

    // --- Device Management Handlers ---
    const fetchUserDevices = async (uuid: string) => {
        const res = await fetch(`/api/devices?user_uuid=${uuid}`)
        const data = await res.json()
        setUserDevices(data || [])
    }

    const handleAddManualDevice = async () => {
        if (!selectedUser || !newDevice.hardware_id) return
        const res = await fetch('/api/devices', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                user_uuid: selectedUser.uuid,
                hardware_id: newDevice.hardware_id,
                label: newDevice.label || "Manual Device"
            })
        })
        if (res.ok) {
            setNewDevice({ hardware_id: "", label: "" })
            fetchUserDevices(selectedUser.uuid)
            fetchUsers() // Update count
        } else {
            const err = await res.text()
            alert("Failed to add device: " + err)
        }
    }

    const handleUnlinkDevice = async (id: number) => {
        if (!confirm("Remove this device?")) return
        await fetch(`/api/devices?id=${id}`, { method: 'DELETE' })
        if (selectedUser) fetchUserDevices(selectedUser.uuid)
        fetchUsers()
    }

    const filteredUsers = users.filter((user: any) =>
        user.uuid?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        user.name?.toLowerCase().includes(searchTerm.toLowerCase())
    )

    return (
        <div className="flex-1 space-y-4 p-8 pt-6">
            <div className="flex items-center justify-between">
                <div>
                    <h2 className="text-3xl font-bold tracking-tight">User Management</h2>
                    <p className="text-zinc-400">Manage users, data limits, and subscriptions.</p>
                </div>
                <div className="flex gap-2">
                    <Dialog open={bulkTemplateDialogOpen} onOpenChange={setBulkTemplateDialogOpen}>
                        <DialogTrigger asChild>
                            <Button variant="outline" className="border-emerald-700 text-emerald-500 hover:bg-emerald-950">
                                <Users className="mr-2 h-4 w-4" /> Bulk Create
                            </Button>
                        </DialogTrigger>
                        <DialogContent className="bg-zinc-900 border-zinc-800 text-white">
                            <DialogHeader>
                                <DialogTitle>Bulk Create Users</DialogTitle>
                                <DialogDescription className="text-zinc-400">Generate multiple users from a template.</DialogDescription>
                            </DialogHeader>
                            <div className="grid gap-4 py-4">
                                <div className="grid gap-2">
                                    <Label>Select Template</Label>
                                    <Select onValueChange={(val) => setBulkTemplateData({ ...bulkTemplateData, template_id: parseInt(val) })}>
                                        <SelectTrigger className="bg-zinc-800 border-zinc-700">
                                            <SelectValue placeholder="Choose a template" />
                                        </SelectTrigger>
                                        <SelectContent className="bg-zinc-800 border-zinc-700 text-white">
                                            {templates.map((t: any) => (
                                                <SelectItem key={t.id} value={t.id.toString()}>{t.name}</SelectItem>
                                            ))}
                                        </SelectContent>
                                    </Select>
                                </div>
                                <div className="grid grid-cols-2 gap-4">
                                    <div className="grid gap-2">
                                        <Label>Count</Label>
                                        <Input type="number" className="bg-zinc-800 border-zinc-700" value={bulkTemplateData.count}
                                            onChange={(e) => setBulkTemplateData({ ...bulkTemplateData, count: parseInt(e.target.value) })} />
                                    </div>
                                    <div className="grid gap-2">
                                        <Label>Strategy</Label>
                                        <Select onValueChange={(val) => setBulkTemplateData({ ...bulkTemplateData, strategy: val })} defaultValue="random">
                                            <SelectTrigger className="bg-zinc-800 border-zinc-700">
                                                <SelectValue />
                                            </SelectTrigger>
                                            <SelectContent className="bg-zinc-800 border-zinc-700 text-white">
                                                <SelectItem value="random">Random (Hash)</SelectItem>
                                                <SelectItem value="sequence">Sequence (Prefix + N)</SelectItem>
                                            </SelectContent>
                                        </Select>
                                    </div>
                                </div>
                                {bulkTemplateData.strategy === 'sequence' && (
                                    <div className="grid gap-2">
                                        <Label>Base Username</Label>
                                        <Input className="bg-zinc-800 border-zinc-700" placeholder="user"
                                            onChange={(e) => setBulkTemplateData({ ...bulkTemplateData, username: e.target.value })} />
                                    </div>
                                )}
                            </div>
                            <DialogFooter>
                                <Button onClick={handleBulkFromTemplate} className="bg-emerald-600 hover:bg-emerald-700">Generate Accounts</Button>
                            </DialogFooter>
                        </DialogContent>
                    </Dialog>

                    <Dialog open={createTemplateDialogOpen} onOpenChange={setCreateTemplateDialogOpen}>
                        <DialogTrigger asChild>
                            <Button variant="secondary" className="bg-zinc-800 hover:bg-zinc-700">
                                <Copy className="mr-2 h-4 w-4" /> From Template
                            </Button>
                        </DialogTrigger>
                        <DialogContent className="bg-zinc-900 border-zinc-800 text-white">
                            <DialogHeader>
                                <DialogTitle>Create User from Template</DialogTitle>
                            </DialogHeader>
                            <div className="grid gap-4 py-4">
                                <div className="grid gap-2">
                                    <Label>Select Template</Label>
                                    <Select onValueChange={(val) => setTemplateFormData({ ...templateFormData, template_id: parseInt(val) })}>
                                        <SelectTrigger className="bg-zinc-800 border-zinc-700">
                                            <SelectValue placeholder="Choose a template" />
                                        </SelectTrigger>
                                        <SelectContent className="bg-zinc-800 border-zinc-700 text-white">
                                            {templates.map((t: any) => (
                                                <SelectItem key={t.id} value={t.id.toString()}>{t.name}</SelectItem>
                                            ))}
                                        </SelectContent>
                                    </Select>
                                </div>
                                <div className="grid gap-2">
                                    <Label>Username</Label>
                                    <Input className="bg-zinc-800 border-zinc-700" value={templateFormData.username}
                                        onChange={(e) => setTemplateFormData({ ...templateFormData, username: e.target.value })} />
                                    <p className="text-[10px] text-zinc-500">Prefix/Suffix from template will be applied automatically.</p>
                                </div>
                            </div>
                            <DialogFooter>
                                <Button onClick={handleCreateFromTemplate} className="bg-emerald-600 hover:bg-emerald-700">Create User</Button>
                            </DialogFooter>
                        </DialogContent>
                    </Dialog>

                    <Dialog open={addDialogOpen} onOpenChange={setAddDialogOpen}>
                        <DialogTrigger asChild>
                            <Button className="bg-emerald-600 hover:bg-emerald-700 text-white">
                                <Plus className="mr-2 h-4 w-4" /> Add User
                            </Button>
                        </DialogTrigger>
                        <DialogContent className="bg-zinc-900 border-zinc-800 text-white">
                            <DialogHeader>
                                <DialogTitle>Add New User</DialogTitle>
                                <DialogDescription className="text-zinc-400">
                                    Create a manual user configuration.
                                </DialogDescription>
                            </DialogHeader>
                            <div className="grid gap-4 py-4">
                                <div className="grid gap-2">
                                    <Label htmlFor="name">Username</Label>
                                    <Input id="name" className="bg-zinc-800 border-zinc-700" value={formData.name}
                                        onChange={(e) => setFormData({ ...formData, name: e.target.value })} />
                                </div>
                                <div className="grid gap-2">
                                    <Label htmlFor="limit">Data Limit (GB)</Label>
                                    <Input id="limit" type="number" className="bg-zinc-800 border-zinc-700" value={formData.limit_gb}
                                        onChange={(e) => setFormData({ ...formData, limit_gb: e.target.value })} />
                                </div>
                                <div className="grid gap-2">
                                    <Label htmlFor="device_limit">Device Limit</Label>
                                    <Input id="device_limit" type="number" className="bg-zinc-800 border-zinc-700" value={formData.device_limit}
                                        onChange={(e) => setFormData({ ...formData, device_limit: parseInt(e.target.value) })} />
                                </div>
                            </div>
                            <DialogFooter>
                                <Button onClick={handleAddUser} className="bg-emerald-600 hover:bg-emerald-700">Create User</Button>
                            </DialogFooter>
                        </DialogContent>
                    </Dialog>
                </div>
            </div>

            <div className="flex items-center gap-2">
                <div className="relative flex-1 max-w-sm">
                    <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-zinc-400" />
                    <Input
                        className="pl-9 bg-zinc-900 border-zinc-800 text-white w-full"
                        placeholder="Search users..."
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                    />
                </div>
                <Button variant="outline" size="icon" onClick={fetchUsers} className="border-dashed border-zinc-700 hover:bg-zinc-800">
                    <RefreshCw className="h-4 w-4 text-zinc-400" />
                </Button>
            </div>

            <div className="rounded-md border border-zinc-800 bg-zinc-900/50">
                <Table>
                    <TableHeader>
                        <TableRow className="border-zinc-800 hover:bg-zinc-900">
                            <TableHead className="text-zinc-400">Username</TableHead>
                            <TableHead className="text-zinc-400">Status</TableHead>
                            <TableHead className="text-zinc-400">Data Usage</TableHead>
                            <TableHead className="text-zinc-400">Limit</TableHead>
                            <TableHead className="text-zinc-400">Devices</TableHead>
                            <TableHead className="text-zinc-400">Expiry</TableHead>
                            <TableHead className="text-right text-zinc-400">Actions</TableHead>
                        </TableRow>
                    </TableHeader>
                    <TableBody>
                        {users.filter(u => u.name.toLowerCase().includes(searchTerm.toLowerCase())).map((user) => (
                            <TableRow key={user.uuid} className="border-zinc-800 text-zinc-300 hover:bg-zinc-800/50">
                                <TableCell className="font-medium text-white">{user.name}</TableCell>
                                <TableCell>
                                    <Badge variant="outline" className={user.status === 'active' ? "border-emerald-500/50 text-emerald-500" : "border-red-500/50 text-red-500"}>
                                        {user.status}
                                    </Badge>
                                </TableCell>
                                <TableCell>{(user.used_bytes / (1024 * 1024 * 1024)).toFixed(2)} GB</TableCell>
                                <TableCell>{(user.limit_gb / (1024 * 1024 * 1024)).toFixed(0)} GB</TableCell>
                                <TableCell >
                                    <div className="flex items-center gap-1">
                                        <Smartphone className="h-3 w-3 text-zinc-500" />
                                        <span>{user.device_count || 0}/{user.device_limit}</span>
                                    </div>
                                </TableCell>
                                <TableCell>{user.expiry === 0 ? "Unlimited" : new Date(user.expiry * 1000).toLocaleDateString()}</TableCell>
                                <TableCell className="text-right">
                                    <div className="flex justify-end gap-2">
                                        <Button
                                            variant="ghost"
                                            size="icon"
                                            className="h-8 w-8 hover:bg-zinc-800"
                                            onClick={() => openConfig(user)}
                                        >
                                            <FileText className="h-4 w-4 text-blue-400" />
                                        </Button>
                                        <Button
                                            variant="ghost"
                                            size="icon"
                                            className="h-8 w-8 hover:bg-zinc-800"
                                            onClick={() => openEditDialog(user, 'general')}
                                            title="Edit User"
                                        >
                                            <Pencil className="h-4 w-4 text-zinc-400" />
                                        </Button>
                                        <Button
                                            variant="ghost"
                                            size="icon"
                                            className="h-8 w-8 hover:bg-zinc-800"
                                            onClick={() => {
                                                setSelectedUser(user)
                                                setRenewDialogOpen(true)
                                            }}
                                            title="Renew UUID"
                                        >
                                            <RefreshCw className="h-4 w-4 text-zinc-500" />
                                        </Button>
                                        <Button
                                            variant="ghost"
                                            size="icon"
                                            className="h-8 w-8 hover:bg-zinc-800"
                                            onClick={() => {
                                                setSelectedUser(user)
                                                setDeleteDialogOpen(true)
                                            }}
                                            title="Delete"
                                        >
                                            <Trash2 className="h-4 w-4 text-red-500" />
                                        </Button>
                                    </div>
                                </TableCell>
                            </TableRow>
                        ))}
                        {filteredUsers.length === 0 && (
                            <TableRow>
                                <TableCell colSpan={7} className="text-center text-zinc-500 py-8">
                                    No users found.
                                </TableCell>
                            </TableRow>
                        )}
                    </TableBody>
                </Table>
            </div>

            {/* Consolidated Edit User Dialog */}
            <Dialog open={editDialogOpen} onOpenChange={setEditDialogOpen}>
                <DialogContent className="bg-zinc-900 border-zinc-800 text-white max-w-4xl h-[600px] flex flex-col">
                    <DialogHeader>
                        <DialogTitle>Edit User: {selectedUser?.name}</DialogTitle>
                        <DialogDescription className="text-zinc-400">
                            Manage user details, devices, and group membership.
                        </DialogDescription>
                    </DialogHeader>

                    {/* Tabs Navigation */}
                    <div className="flex space-x-1 bg-zinc-800/50 p-1 rounded-lg">
                        {['general', 'devices', 'groups'].map((tab) => (
                            <button
                                key={tab}
                                onClick={() => setActiveTab(tab)}
                                className={`flex-1 py-1.5 text-sm font-medium rounded-md transition-all ${activeTab === tab
                                    ? 'bg-zinc-700 text-white shadow'
                                    : 'text-zinc-400 hover:text-zinc-200'
                                    }`}
                            >
                                {tab.charAt(0).toUpperCase() + tab.slice(1)}
                            </button>
                        ))}
                    </div>

                    <div className="flex-1 overflow-y-auto py-4">
                        {/* Tab: General */}
                        {activeTab === 'general' && (
                            <div className="space-y-4 max-w-lg mx-auto">
                                <div className="grid gap-2">
                                    <Label htmlFor="edit-name">Name</Label>
                                    <Input
                                        id="edit-name"
                                        className="bg-zinc-800 border-zinc-700"
                                        value={formData.name}
                                        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                    />
                                </div>
                                <div className="grid gap-2">
                                    <Label htmlFor="edit-limit">Quota (GB)</Label>
                                    <Input
                                        id="edit-limit"
                                        type="number"
                                        className="bg-zinc-800 border-zinc-700"
                                        value={formData.limit_gb}
                                        onChange={(e) => setFormData({ ...formData, limit_gb: e.target.value })}
                                    />
                                </div>
                                <div className="grid gap-2">
                                    <Label htmlFor="edit-dev-limit">Max Devices</Label>
                                    <Input
                                        id="edit-dev-limit"
                                        type="number"
                                        className="bg-zinc-800 border-zinc-700"
                                        value={formData.device_limit}
                                        onChange={(e) => setFormData({ ...formData, device_limit: Number(e.target.value) })}
                                    />
                                </div>
                                <div className="pt-4">
                                    <Button onClick={handleEditUser} className="w-full">Save Changes</Button>
                                </div>
                            </div>
                        )}

                        {/* Tab: Devices */}
                        {activeTab === 'devices' && (
                            <div className="space-y-4">
                                <div className="rounded-md border border-zinc-800">
                                    <Table>
                                        <TableHeader>
                                            <TableRow className="border-zinc-800 hover:bg-zinc-900">
                                                <TableHead>Label</TableHead>
                                                <TableHead>Hardware ID</TableHead>
                                                <TableHead>Seen</TableHead>
                                                <TableHead></TableHead>
                                            </TableRow>
                                        </TableHeader>
                                        <TableBody>
                                            {userDevices.map((dev) => (
                                                <TableRow key={dev.id} className="border-zinc-800">
                                                    <TableCell>{dev.label}</TableCell>
                                                    <TableCell className="font-mono text-xs text-zinc-400">{dev.hardware_id}</TableCell>
                                                    <TableCell className="text-xs text-zinc-500">{new Date(dev.last_seen).toLocaleDateString()}</TableCell>
                                                    <TableCell>
                                                        <Button variant="ghost" size="sm" onClick={() => handleUnlinkDevice(dev.id)}>
                                                            <Trash2 className="h-4 w-4 text-red-500" />
                                                        </Button>
                                                    </TableCell>
                                                </TableRow>
                                            ))}
                                            {userDevices.length === 0 && (
                                                <TableRow>
                                                    <TableCell colSpan={4} className="text-center text-zinc-500">No devices linked.</TableCell>
                                                </TableRow>
                                            )}
                                        </TableBody>
                                    </Table>
                                </div>
                                <div className="flex gap-2 items-end border-t border-zinc-800 pt-4">
                                    <div className="grid gap-2 flex-1">
                                        <Label>Hardware ID</Label>
                                        <Input
                                            placeholder="Enter Hardware ID"
                                            className="bg-zinc-800 border-zinc-700"
                                            value={newDevice.hardware_id}
                                            onChange={(e) => setNewDevice({ ...newDevice, hardware_id: e.target.value })}
                                        />
                                    </div>
                                    <div className="grid gap-2 w-1/3">
                                        <Label>Label</Label>
                                        <Input
                                            placeholder="Laptop..."
                                            className="bg-zinc-800 border-zinc-700"
                                            value={newDevice.label}
                                            onChange={(e) => setNewDevice({ ...newDevice, label: e.target.value })}
                                        />
                                    </div>
                                    <Button onClick={handleAddManualDevice} disabled={!newDevice.hardware_id}>Add</Button>
                                </div>
                            </div>
                        )}

                        {/* Tab: Groups */}
                        {activeTab === 'groups' && (
                            <div className="space-y-6 max-w-lg mx-auto pt-4">
                                <div className="grid gap-2">
                                    <Label>Current Group</Label>
                                    <div className="flex items-center justify-between bg-zinc-800 p-3 rounded-md border border-zinc-700">
                                        <span className="text-zinc-200">
                                            {selectedUser?.group_name || "No Group Assigned"}
                                        </span>
                                        {selectedUser?.group_id && (
                                            <Button variant="destructive" size="sm" onClick={confirmRemoveGroup}>
                                                Remove
                                            </Button>
                                        )}
                                    </div>
                                </div>
                                <div className="grid gap-2">
                                    <Label>Assign New Group</Label>
                                    <div className="flex gap-2">
                                        <Select value={selectedGroup} onValueChange={setSelectedGroup}>
                                            <SelectTrigger className="bg-zinc-800 border-zinc-700 flex-1">
                                                <SelectValue placeholder="Select group" />
                                            </SelectTrigger>
                                            <SelectContent className="bg-zinc-800 border-zinc-700">
                                                {groups.map((group: any) => (
                                                    <SelectItem key={group.id} value={group.id.toString()}>{group.name}</SelectItem>
                                                ))}
                                            </SelectContent>
                                        </Select>
                                        <Button onClick={handleAssignGroup} disabled={!selectedGroup}>Assign</Button>
                                    </div>
                                </div>
                            </div>
                        )}
                    </div>
                </DialogContent>
            </Dialog >

            {/* Other Dialogs (Config, Renew, Delete) - Keep these separate as they are distinct actions */}
            {/* View Config Dialog */}
            <Dialog open={configDialogOpen} onOpenChange={setConfigDialogOpen}>
                <DialogContent className="bg-zinc-900 border-zinc-800 text-white max-w-2xl">
                    <DialogHeader>
                        <DialogTitle>User Configuration</DialogTitle>
                        <DialogDescription className="text-zinc-400">
                            Client configs for {selectedUser?.name}.
                        </DialogDescription>
                    </DialogHeader>
                    <div className="bg-zinc-950 p-3 rounded-md mb-4 flex items-center justify-between gap-2 border border-zinc-800 mt-4">
                        <div className="flex-col overflow-hidden">
                            <span className="text-[10px] uppercase text-zinc-500 font-bold block">Subscription URL</span>
                            <div className="truncate text-xs font-mono text-blue-400">
                                {subscriptionUrl}
                            </div>
                        </div>
                        <Button
                            size="sm"
                            variant="secondary"
                            className="h-8 text-xs shrink-0 bg-blue-600/10 text-blue-400 hover:bg-blue-600/20 border border-blue-600/20"
                            onClick={() => {
                                navigator.clipboard.writeText(subscriptionUrl);
                                alert("Subscription URL copied!");
                            }}
                        >
                            <Copy className="h-3 w-3 mr-2" /> Copy Link
                        </Button>
                    </div>
                    <div className="max-h-[60vh] overflow-y-auto space-y-4 py-4 pr-2">
                        {(() => {
                            try {
                                const data = JSON.parse(configData || "{}");
                                if (!data.configs || data.configs.length === 0) {
                                    return (
                                        <div className="text-center text-zinc-500 py-8">
                                            <p>No configurations assigned.</p>
                                            <p className="text-xs mt-2">Assign this user to a group with active Core Configs.</p>
                                        </div>
                                    );
                                }

                                return data.configs.map((conf: any, i: number) => {
                                    // Use _meta if available, fallback to parsing label
                                    const coreName = conf._meta?.core_name || conf.label?.split(" - ")[0] || "Unknown Core";
                                    const protocol = conf._meta?.protocol_display || conf.protocol?.toUpperCase() || "TCP";

                                    return (
                                        <div key={i} className="bg-zinc-800 rounded-lg p-4 border border-zinc-700">
                                            <div className="flex items-center justify-between mb-2">
                                                <div className="flex items-center gap-2">
                                                    <span className="font-semibold text-white">{coreName}</span>
                                                    <Badge className="bg-blue-600 hover:bg-blue-700">
                                                        {protocol}
                                                    </Badge>
                                                </div>
                                                <div className="text-xs text-zinc-500 font-mono">
                                                    {conf.server}:{conf.port}
                                                </div>
                                            </div>

                                            <div className="relative">
                                                <pre className="bg-zinc-950 p-3 rounded text-xs font-mono text-zinc-300 overflow-x-auto whitespace-pre-wrap">
                                                    {JSON.stringify(conf, null, 2)}
                                                </pre>
                                                <Button
                                                    variant="secondary"
                                                    size="sm"
                                                    className="absolute top-2 right-2 h-6 text-xs"
                                                    onClick={() => {
                                                        navigator.clipboard.writeText(JSON.stringify(conf, null, 2));
                                                        alert("Config copied!");
                                                    }}
                                                >
                                                    <Copy className="h-3 w-3 mr-1" /> Copy JSON
                                                </Button>
                                                <Button
                                                    variant="secondary"
                                                    size="sm"
                                                    className="absolute top-2 right-24 h-6 text-xs bg-emerald-600/20 text-emerald-400 hover:bg-emerald-600/30"
                                                    onClick={() => {
                                                        const link = generateLink(conf, conf.protocol);
                                                        if (link) {
                                                            navigator.clipboard.writeText(link);
                                                            alert("Link copied!");
                                                        } else {
                                                            alert("Link generation not supported for " + conf.protocol);
                                                        }
                                                    }}
                                                >
                                                    <Copy className="h-3 w-3 mr-1" /> Copy Link
                                                </Button>
                                            </div>
                                        </div>
                                    );
                                });
                            } catch (e) {
                                return <Textarea className="bg-zinc-800 border-zinc-700" value={configData} readOnly />;
                            }
                        })()}
                    </div>

                    <DialogFooter>
                        <Button onClick={handleCopyConfig} variant="outline" className="border-zinc-700">
                            {copied ? <Check className="mr-2 h-4 w-4" /> : <Copy className="mr-2 h-4 w-4" />}
                            {copied ? "Copied All" : "Copy Full JSON"}
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>

            {/* Renew UUID Confirmation */}
            <AlertDialog open={renewDialogOpen} onOpenChange={setRenewDialogOpen}>
                <AlertDialogContent className="bg-zinc-900 border-zinc-800 text-white">
                    <AlertDialogHeader>
                        <AlertDialogTitle>Renew UUID?</AlertDialogTitle>
                        <AlertDialogDescription className="text-zinc-400">
                            This will generate a new UUID for <strong>{selectedUser?.name}</strong>.
                            The old UUID will no longer work. You must update the client configuration.
                        </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                        <AlertDialogCancel className="bg-zinc-800 border-zinc-700">Cancel</AlertDialogCancel>
                        <AlertDialogAction onClick={handleRenewUUID} className="bg-blue-600 hover:bg-blue-700">
                            Renew
                        </AlertDialogAction>
                    </AlertDialogFooter>
                </AlertDialogContent>
            </AlertDialog>

            {/* Delete Confirmation */}
            <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
                <AlertDialogContent className="bg-zinc-900 border-zinc-800 text-white">
                    <AlertDialogHeader>
                        <AlertDialogTitle>Are you sure?</AlertDialogTitle>
                        <AlertDialogDescription className="text-zinc-400">
                            This will permanently delete the user <strong>{selectedUser?.name}</strong> and all associated data.
                        </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                        <AlertDialogCancel className="bg-zinc-800 border-zinc-700">Cancel</AlertDialogCancel>
                        <AlertDialogAction onClick={handleDeleteUser} className="bg-red-600 hover:bg-red-700">
                            Delete
                        </AlertDialogAction>
                    </AlertDialogFooter>
                </AlertDialogContent>
            </AlertDialog>
            <AlertDialog open={removeGroupDialogOpen} onOpenChange={setRemoveGroupDialogOpen}>
                <AlertDialogContent className="bg-zinc-900 border-zinc-800 text-white">
                    <AlertDialogHeader>
                        <AlertDialogTitle>Unassign Group?</AlertDialogTitle>
                        <AlertDialogDescription className="text-zinc-400">
                            Remove <strong>{selectedUser?.name}</strong> from their current group?
                            They will lose access to group-assigned inbound configs.
                        </AlertDialogDescription>
                    </AlertDialogHeader>
                    <AlertDialogFooter>
                        <AlertDialogCancel className="bg-zinc-800 border-zinc-700">Cancel</AlertDialogCancel>
                        <AlertDialogAction onClick={handleRemoveGroup} className="bg-red-600 hover:bg-red-700">
                            Unassign
                        </AlertDialogAction>
                    </AlertDialogFooter>
                </AlertDialogContent>
            </AlertDialog>
        </div >
    )
}
