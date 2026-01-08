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

    const handleViewConfig = async (user: any) => {
        setSelectedUser(user)
        const res = await fetch(`/api/user/config?uuid=${user.uuid}`, { cache: 'no-store' })
        const config = await res.json()
        setConfigData(JSON.stringify(config, null, 2))
        setConfigDialogOpen(true)
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

    const handleRemoveGroup = async () => {
        if (!selectedUser || !selectedUser.group_id) return
        if (!confirm(`Remove ${selectedUser.name} from group?`)) return

        await fetch(`/api/users/assign-group?user_uuid=${selectedUser.uuid}&group_id=${selectedUser.group_id}`, {
            method: 'DELETE'
        })
        setSelectedGroup("")
        fetchUsers()
        // Update selectedUser locally to reflect change immediately in UI if needed, or rely on fetchUsers
        setSelectedUser({ ...selectedUser, group_id: undefined, group_name: undefined })
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
                <h2 className="text-3xl font-bold tracking-tight">User Management</h2>
                {/* ... (Add User Button/Dialog - Keep as is) ... */}
                <Dialog open={addDialogOpen} onOpenChange={setAddDialogOpen}>
                    <DialogTrigger asChild>
                        <Button>
                            <Plus className="mr-2 h-4 w-4" /> Add User
                        </Button>
                    </DialogTrigger>
                    <DialogContent className="bg-zinc-900 border-zinc-800 text-white">
                        <DialogHeader>
                            <DialogTitle>Add New User</DialogTitle>
                            <DialogDescription className="text-zinc-400">
                                Create a new VPN user account.
                            </DialogDescription>
                        </DialogHeader>
                        <div className="grid gap-4 py-4">
                            <div className="grid gap-2">
                                <Label htmlFor="name">Name</Label>
                                <Input
                                    id="name"
                                    className="bg-zinc-800 border-zinc-700"
                                    value={formData.name}
                                    onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                    placeholder="John Doe"
                                />
                            </div>
                            <div className="grid grid-cols-4 items-center gap-4">
                                <Label htmlFor="limit" className="text-right">
                                    Limit (GB)
                                </Label>
                                <Input
                                    id="limit"
                                    type="number"
                                    value={formData.limit_gb}
                                    onChange={(e) => setFormData({ ...formData, limit_gb: e.target.value })}
                                    className="col-span-3 bg-zinc-800 border-zinc-700"
                                    placeholder="30"
                                />
                            </div>
                            <div className="grid grid-cols-4 items-center gap-4">
                                <Label htmlFor="dev_limit" className="text-right">
                                    Max Devices
                                </Label>
                                <Input
                                    id="dev_limit"
                                    type="number"
                                    value={formData.device_limit}
                                    onChange={(e) => setFormData({ ...formData, device_limit: Number(e.target.value) })}
                                    className="col-span-3 bg-zinc-800 border-zinc-700"
                                    placeholder="3"
                                />
                            </div>
                        </div>
                        <DialogFooter>
                            <Button onClick={handleAddUser}>Create User</Button>
                        </DialogFooter>
                    </DialogContent>
                </Dialog>
            </div>

            {/* ... (Search Bar - Keep as is) ... */}
            <div className="flex items-center py-4">
                <div className="relative w-full max-w-sm">
                    <Search className="absolute left-2 top-2.5 h-4 w-4 text-muted-foreground" />
                    <Input
                        placeholder="Search by UUID or name..."
                        className="pl-8 bg-zinc-900 border-zinc-700"
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                    />
                </div>
            </div>

            {/* Users Table */}
            <div className="rounded-md border border-zinc-800 bg-zinc-900 text-white">
                <Table>
                    <TableHeader>
                        <TableRow className="border-zinc-800 hover:bg-zinc-800">
                            <TableHead className="w-[100px]">Status</TableHead>
                            <TableHead>Name</TableHead>
                            <TableHead>Group</TableHead>
                            <TableHead>UUID</TableHead>
                            <TableHead>Usage / Limit</TableHead>
                            <TableHead>Devices</TableHead>
                            <TableHead className="text-right">Actions</TableHead>
                        </TableRow>
                    </TableHeader>
                    <TableBody>
                        {filteredUsers.map((user: any) => (
                            <TableRow key={user.uuid} className="border-zinc-800 hover:bg-zinc-800">
                                <TableCell>
                                    <Badge variant="outline" className={
                                        user.status === 'active'
                                            ? "bg-green-500/10 text-green-500 border-green-500/20"
                                            : "bg-red-500/10 text-red-500 border-red-500/20"
                                    }>
                                        {user.status}
                                    </Badge>
                                </TableCell>
                                <TableCell className="font-medium">{user.name || 'Unnamed'}</TableCell>
                                <TableCell>
                                    {user.group_name && user.group_name !== "No Group" ? (
                                        <Badge variant="secondary" className="bg-purple-500/10 text-purple-400 hover:bg-purple-500/20 border-purple-500/20">
                                            {user.group_name}
                                        </Badge>
                                    ) : (
                                        <span className="text-zinc-600 text-sm">No Group</span>
                                    )}
                                </TableCell>
                                <TableCell className="font-mono text-xs text-zinc-400">{user.uuid.substring(0, 8)}...</TableCell>
                                <TableCell>
                                    <div className="flex items-center gap-2">
                                        <span>{((user.used_bytes || 0) / 1e9).toFixed(2)} GB</span>
                                        <span className="text-zinc-500">/</span>
                                        <span>{user.limit_gb || 0} GB</span>
                                    </div>
                                    <div className="mt-1 h-1.5 w-24 rounded-full bg-zinc-800">
                                        <div
                                            className="h-1.5 rounded-full bg-emerald-500"
                                            style={{ width: `${Math.min((user.used_bytes || 0) / (user.limit_gb * 1e9) * 100, 100)}%` }}
                                        />
                                    </div>
                                </TableCell>
                                <TableCell>
                                    <div className="flex items-center gap-2">
                                        <Smartphone className="h-4 w-4 text-zinc-500" />
                                        <span className={user.device_count >= user.device_limit ? "text-red-400" : "text-zinc-300"}>
                                            {user.device_count} / {user.device_limit}
                                        </span>
                                    </div>
                                </TableCell>
                                <TableCell className="text-right">
                                    <div className="flex justify-end gap-1">
                                        <Button
                                            variant="ghost"
                                            size="icon"
                                            className="h-8 w-8"
                                            onClick={() => openEditDialog(user, 'devices')}
                                            title="Manage Devices"
                                        >
                                            <Smartphone className="h-4 w-4 text-emerald-400" />
                                        </Button>

                                        <Button
                                            variant="ghost"
                                            size="icon"
                                            className="h-8 w-8"
                                            onClick={() => openEditDialog(user, 'groups')}
                                            title="Assign Group"
                                        >
                                            <Users className="h-4 w-4 text-purple-400" />
                                        </Button>
                                        <Button
                                            variant="ghost"
                                            size="icon"
                                            className="h-8 w-8"
                                            onClick={() => handleViewConfig(user)}
                                            title="View Config"
                                        >
                                            <FileText className="h-4 w-4" />
                                        </Button>
                                        <Button
                                            variant="ghost"
                                            size="icon"
                                            onClick={() => openEditDialog(user, 'general')}
                                            className="text-white bg-blue-600/20 hover:bg-blue-600/40"
                                            title="Edit User"
                                        >
                                            <Pencil className="h-4 w-4 text-blue-400" />
                                        </Button>
                                        <Button
                                            variant="ghost"
                                            size="icon"
                                            className="h-8 w-8"
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
                                            className="h-8 w-8"
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
                                            <Button variant="destructive" size="sm" onClick={handleRemoveGroup}>
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
            </Dialog>

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
                                                    <Copy className="h-3 w-3 mr-1" /> Copy
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
        </div>
    )
}
